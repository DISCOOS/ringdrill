// The MCP tool table — names, descriptions, input schemas, and what each tool
// does in terms of a *backend*.
//
// Two transports serve these: the local stdio server (`ringdrill-mcp.mjs`, backed
// by the CLI as a subprocess) and the hosted Netlify function (backed by the
// cross-compiled compiler in-process, ADR-0060). ADR-0060 requires that "the two
// share one tool table", and this is it: a description improved for one is improved
// for both, and a tool cannot exist in one and not the other.
//
// A backend implements six operations, all `async (args) => object`:
//
//   schema()                        the JSON Schema
//   create(args)                    -> {document, …}
//   analyze({document|document_path, strict})  -> {errors, warnings, …}
//   build({document|document_path, strict})    -> {contentHash, archive, …}
//   render({document|document_path, audience, lang, exercise, station, format})
//                                              -> {markdown, …}
//   searchCatalog({limit, cursor})  -> {items, nextCursor?}
//   getPlan({slug, version})        -> {document, …}
//
// `build`'s `archive` is one field with a discriminated shape rather than a set of
// transport-specific keys (ADR-0070) — `{kind: 'file', path}`, `{kind: 'url', url,
// expires_at}` or `{kind: 'inline', base64}`. That is deliberate: a key whose
// *presence* depended on which backend answered would be the drift the parity test
// below exists to catch, so the discriminator is a value an agent reads instead.
//
// The four document operations answer with a verdict, and their tools always
// surface it as `ok` — `verdict()` below supplies it, so a backend need only say
// `ok: false` when something did not compile. That uniformity is the contract a
// client sees, and it is the one thing here the two backends had actually drifted
// on: `mcp/tests/backend-parity.test.mjs` now runs both over the same input and
// compares the keys. A backend may return only what it can honestly produce — it
// must not invent a field the other cannot, or echo a path that will not exist by
// the time the client reads it.
//
// Deliberately no Node built-ins here: this module is imported by a Netlify
// function, so it stays plain data plus calls into the injected backend.

/// Shared argument description, so the two document-taking tools agree.
///
/// It states the size limit and the real scale on purpose. Neither used to appear in
/// any channel an agent can read — only in `mcp/README.md`, which a connector-only
/// client cannot fetch, and in the error you get by exceeding the cap. So an agent
/// had nothing to anchor "is this too big" to, and one duly invented a ceiling:
/// a cold run judged a 67 KB plan "just large enough that passing it around as chat
/// text is awkward", split it, and then abandoned the hosted tools for the local CLI.
/// Nothing had enforced a limit. A number is cheaper than a guess.
const SOURCE_DOCUMENT_ARG = {
    type: 'string',
    description:
        'The source document, as YAML text. Call `schema` for its shape, or ' +
        '`create_plan` for a starting point. Documents up to 512 KB are accepted ' +
        'and a real plan is 60-90 KB, so send the whole thing in one call — do not ' +
        'split it, summarise it, or send an excerpt.',
};

/// The local alternative to sending the text (ADR-0064).
///
/// An authoring loop calls these tools repeatedly on the same document, and a
/// real plan runs to tens of kilobytes — so resending it spends the agent's
/// context on text that has not changed. A path spends a filename instead.
///
/// Only the stdio server can honour it; the hosted one has no access to the
/// caller's filesystem and says so rather than guessing.
const SOURCE_DOCUMENT_PATH_ARG = {
    type: 'string',
    description:
        'Path to the source document on disk, instead of `document`. Local ' +
        '(stdio) server only — use this while iterating so a large document is ' +
        'not resent on every call. The hosted server rejects it.',
};

/// Ask the hosted server to hold this document so later calls can name it
/// (ADR-0064).
///
/// Off by default, and deliberately the caller's choice rather than the server's:
/// retention is a promise about what the service is, so an author who does not ask
/// gets a server that compiles what it is sent and keeps nothing. Set it when you
/// intend to iterate — not reflexively, because setting it opts the author into
/// retention on their behalf.
const CACHE_ARG = {
    type: 'boolean',
    description:
        'Hosted server only: hold this document under its content hash so later ' +
        'calls can pass `document_hash` instead of resending it. Off by default ' +
        '— the server keeps nothing unless asked. Set it when you are about to ' +
        'iterate on a large document; the response then carries the hash.',
};

/// Where the stdio backend should write the archive (ADR-0070).
///
/// The local mirror of `document_path`, and the same argument for it: the CLI has
/// always written wherever it was told, as this user, so naming the destination adds
/// no capability and saves the bytes a trip through the transcript.
const OUTPUT_PATH_ARG = {
    type: 'string',
    description:
        'Where to write the .drill archive. Local (stdio) server only — the ' +
        'hosted server rejects it and answers with a download URL instead. ' +
        'Without it the archive still lands on disk, under a content-addressed ' +
        'path in the temp directory.',
};

/// Ask for the archive bytes in the response, retaining nothing (ADR-0070).
///
/// The fallback, not a forbidden option — and worded as one, because the first draft
/// said only "do not ask for this", which left a client that *cannot* follow a URL
/// with no sanctioned way to obtain a build at all. A hosted handle depends on an
/// HTTP client that MCP does not guarantee the caller has.
const INLINE_ARG = {
    type: 'boolean',
    description:
        'Return the archive as base64 in the response instead of a handle. Off ' +
        'by default, because a real plan is ~100 KB of base64 that no agent ' +
        'reads and many clients truncate. Use it when you cannot follow a URL ' +
        '(no HTTP client, no network) or when a programmatic caller wants the ' +
        'bytes — it is also the way to keep the hosted server from holding the ' +
        'archive at all.',
};

/// Name a document the server is already holding, instead of resending it.
const DOCUMENT_HASH_ARG = {
    type: 'string',
    description:
        'A `document_hash` from an earlier response, instead of `document`. ' +
        'Expires after about half an hour; a miss says so and asks you to resend, ' +
        'so it costs a slower loop rather than a failure.',
};

/// `document`, `document_path` or `document_hash` — any one of the three.
///
/// Expressed as `anyOf` rather than `required`, because a schema demanding
/// `document` would make the other two look invalid.
const DOCUMENT_OR_PATH = [
    { required: ['document'] },
    { required: ['document_path'] },
    { required: ['document_hash'] },
];

/// Guarantees the `ok` a document operation's answer is documented to carry.
///
/// The four document tools answer with a verdict — "did this compile" — and the
/// header of this file states the contract as `-> {ok, …}`. Only the hosted backend
/// kept it. The CLI backend injects `ok: false` when the CLI exits non-zero and adds
/// nothing on success, so `ok` was *absent on success and false on failure*: a
/// client writing the obvious `if (result.ok)` got the answer backwards on stdio and
/// right on the hosted endpoint.
///
/// Applied here rather than in either backend because here is the only place both
/// pass through — a fix in one is a fix that can drift again. `mcp/tests/
/// backend-parity.test.mjs` is what keeps them honest.
///
/// Not applied to every tool: `schema` answers with the JSON Schema *itself*, and
/// wrapping that would make it describe a document nobody writes. The catalog tools
/// answer with a collection, not a verdict.
const verdict = (run) => async (args) => ({ ok: true, ...(await run(args)) });

/// The tool surface.
///
/// Descriptions are the agent's only documentation, so they say what the tool is
/// *for* and which mistake it prevents — not just what it does. `publish` is
/// deliberately absent: the catalog is a shared, wiki-model corpus and an agent
/// should not write to it unattended (DESIGN-014).
export function toolsFor(backend) {
    return [
        {
            name: 'schema',
            description:
                "The source format's JSON Schema. Read this before writing a " +
                'document: it is generated from the same field table the compiler ' +
                'validates against, so it cannot describe a field `build_plan` ' +
                'will reject. Note especially that derived fields (schedule, ' +
                'endTime, indices, uuids, contentHash) are absent by design — the ' +
                'compiler fills them, and numbering comes from list position, ' +
                'never from a name.',
            inputSchema: { type: 'object', properties: {} },
            run: () => backend.schema(),
        },
        {
            name: 'search_catalog',
            description:
                'List published plans in the open catalog, with their tags. Read ' +
                'one or two with `get_plan` for **scope and prose** — how much a ' +
                'station really carries, what tone a brief uses. Take the format ' +
                'itself from `schema` and `create_plan` instead: the catalog is a ' +
                'shared, wiki-model corpus, so a published plan may predate the ' +
                'current format and is not a template to copy.',
            inputSchema: {
                type: 'object',
                properties: {
                    limit: {
                        type: 'integer',
                        description: 'Page size. Default 50.',
                    },
                    cursor: { type: 'string', description: 'Pagination cursor.' },
                    query: {
                        type: 'string',
                        description:
                            'Case-insensitive filter over name, slug and tags. ' +
                            'Applied to the page fetched, not server-side.',
                    },
                },
            },
            run: async ({ limit, cursor, query }) => {
                const page = await backend.searchCatalog({ limit, cursor });
                if (!query) return page;
                const needle = query.toLowerCase();
                return {
                    ...page,
                    items: (page.items ?? []).filter((i) =>
                        [i.name, i.slug, ...(i.tags ?? [])]
                            .join(' ')
                            .toLowerCase()
                            .includes(needle),
                    ),
                };
            },
        },
        {
            name: 'get_plan',
            description:
                'Download a published plan and return it as a *source document* ' +
                '— the same format you write, not the raw archive. The uuids it ' +
                'carries mean an edited copy rebuilds onto the same plan rather ' +
                'than a duplicate. Read it for scope and prose, not for structure: ' +
                'a published plan can be older than the format, so it may carry ' +
                'flat descriptions, values that belong in variables, or numbering ' +
                'written into a name. `analyze_plan` will tell you which.',
            inputSchema: {
                type: 'object',
                properties: {
                    slug: { type: 'string', description: 'Catalog slug.' },
                    version: {
                        type: 'integer',
                        description: 'Default: latest.',
                    },
                },
                required: ['slug'],
            },
            run: (args) => backend.getPlan(args),
        },
        {
            name: 'create_plan',
            description:
                'Scaffold a starting source document. Faster and safer than ' +
                'writing one from scratch: it builds clean as-is and demonstrates ' +
                'the scenario layer (a station-owned location and person addressed ' +
                'by slug, prose referencing them, a role play portraying the ' +
                'person).',
            inputSchema: {
                type: 'object',
                properties: {
                    name: { type: 'string', description: 'Plan name.' },
                    exercises: { type: 'integer', description: 'Default 1.' },
                    teams: { type: 'integer', description: 'Default 4.' },
                    stations: {
                        type: 'integer',
                        description:
                            'Stations per exercise. Default: the team count, the ' +
                            'fewest a rotation can have.',
                    },
                    rounds: {
                        type: 'integer',
                        description: 'Default: the station count.',
                    },
                    lang: {
                        type: 'string',
                        description: "ISO 639-1 content language. Default 'en'.",
                    },
                    bare: {
                        type: 'boolean',
                        description: 'Omit the worked scenario example.',
                    },
                },
                required: ['name'],
            },
            run: verdict((args) => backend.create(args)),
        },
        {
            name: 'analyze_plan',
            description:
                'Check a source document without building it. Catches what ' +
                'compiles fine but will not render: a {{var.x}} naming no ' +
                'declared variable, a {{station.loc.x}} on a station that owns no ' +
                'such location, a misspelled or wrong-scope reference. Always run ' +
                'this before presenting a document as finished — tokens are stored ' +
                'raw, so these mistakes are invisible until a reader is holding ' +
                'the brief. It also reports `suggestions`: places the document ' +
                'works *around* the format rather than with it — a coordinate typed ' +
                'into prose instead of a location, a talegruppe repeated in six ' +
                'fields instead of a variable, a role play portraying nobody the ' +
                'station declares. Those never block a build, and acting on them is ' +
                'what separates a plan an author can edit from a transcription.',
            inputSchema: {
                type: 'object',
                properties: {
                    document: SOURCE_DOCUMENT_ARG,
                    document_path: SOURCE_DOCUMENT_PATH_ARG,
                    document_hash: DOCUMENT_HASH_ARG,
                    cache: CACHE_ARG,
                    strict: {
                        type: 'boolean',
                        description: 'Treat warnings as errors.',
                    },
                },
                anyOf: DOCUMENT_OR_PATH,
            },
            run: verdict((args) => backend.analyze(args)),
        },
        {
            name: 'build_plan',
            description:
                'Compile a source document to a .drill archive, plus the plan ' +
                'summary and content hash. The archive comes back as a handle in ' +
                '`archive`, not as bytes in the response: `kind: "file"` with a ' +
                '`path` on a local server, `kind: "url"` with a `url` and ' +
                '`expires_at` on the hosted one. That url is a plain GET returning ' +
                'the .drill as an attachment — fetch it yourself if you need the ' +
                'file locally, and give it to the author either way. If you have no ' +
                'way to fetch a url, pass `inline: true` for `kind: "inline"` and ' +
                'base64 instead. Does not publish: the catalog is a shared corpus, ' +
                'so putting a plan in it stays a human step.',
            inputSchema: {
                type: 'object',
                properties: {
                    document: SOURCE_DOCUMENT_ARG,
                    document_path: SOURCE_DOCUMENT_PATH_ARG,
                    document_hash: DOCUMENT_HASH_ARG,
                    cache: CACHE_ARG,
                    output_path: OUTPUT_PATH_ARG,
                    inline: INLINE_ARG,
                    strict: {
                        type: 'boolean',
                        description: 'Refuse to build if there are warnings.',
                    },
                },
                anyOf: DOCUMENT_OR_PATH,
            },
            run: verdict((args) => backend.build(args)),
        },
        {
            name: 'render_plan',
            description:
                'Render the markdown brief for a source document — what a ' +
                'participant, instructor or director actually reads. The fastest ' +
                'way to check that a plan makes sense: unresolved tokens and thin ' +
                'sections are obvious in the brief and invisible in the source.',
            inputSchema: {
                type: 'object',
                properties: {
                    document: SOURCE_DOCUMENT_ARG,
                    document_path: SOURCE_DOCUMENT_PATH_ARG,
                    document_hash: DOCUMENT_HASH_ARG,
                    cache: CACHE_ARG,
                    audience: {
                        type: 'string',
                        enum: [
                            'participant',
                            'actor',
                            'instructor',
                            'director',
                            'other',
                        ],
                        description:
                            'One per staff role, plus participant — the printed ' +
                            'handout, which withholds every staff-facing field ' +
                            '(ADR-0063). Default participant.',
                    },
                    lang: {
                        type: 'string',
                        description:
                            "Default: the plan's own content language.",
                    },
                    exercise: {
                        type: 'integer',
                        description:
                            '1-based exercise number to scope to. Default: whole ' +
                            'plan.',
                    },
                    station: {
                        type: 'integer',
                        description:
                            '1-based station within the scoped exercise. ' +
                            'Requires `exercise`. Scoping keeps the station its ' +
                            'own code, so 1c stays 1c.',
                    },
                    format: {
                        type: 'string',
                        enum: ['full', 'summary'],
                        description:
                            '"summary" returns the brief\'s shape — headings, ' +
                            'and which sections each scope carries — without the ' +
                            'prose. Use it while iterating: a real plan\'s brief ' +
                            'runs to tens of kilobytes, and "does this read" does ' +
                            'not need all of it. Default full.',
                    },
                },
                anyOf: DOCUMENT_OR_PATH,
            },
            run: verdict((args) => backend.render(args)),
        },
    ];
}

/// The protocol version both transports advertise.
export const PROTOCOL_VERSION = '2024-11-05';

/// What `initialize` returns as `instructions` — the one channel most clients
/// inject into the system prompt, so the only guidance certain to be read
/// (ADR-0065).
///
/// Kept short on purpose. It carries only rules that are unsafe to break, or that
/// an agent gets wrong *by default* — the 80-column wrap is the second kind: every
/// coding agent reaches for it, and the damage is invisible in the source and in
/// the rendered brief, showing up only in the editor an author actually types in.
/// Everything explanatory belongs in the authoring guide instead, which is what the
/// closing pointer is for.
///
/// Anything named here must still be true of `skills/ringdrill-plan-authoring/`;
/// `netlify/tests/mcp-endpoint.test.mjs` checks the pair for drift.
export const INSTRUCTIONS = `These tools compile a drill plan from one YAML source document.

Rules the schema cannot express, and that are easy to get wrong:

- Break markdown fields at sentence ends, never at a fixed column width. Authors
  edit these in a section editor that honours your newlines, so an 80-column wrap
  arrives as a ragged break mid-sentence.
- Numbering is derived from list position. Never write "2a)" or "#3" into a name —
  the app renders the code itself, and a name that carries one renders it twice.
- A token is content, not something to resolve while writing. Write {{var.x}} and
  {{station.loc.y.position}} literally; they resolve at render.
- Three fields the app asks for by name: an exercise's \`method\`, a station's
  \`description\` and a roleplay's \`description\`. A post with no description shows
  "Missing: Station description" in its own card until someone fills it. They are the
  easiest to skip, because a source booklet has no heading that maps to them — it
  gives you the scenario and the order, which land in \`situation\` and \`mission\`.
  Write them from what the rest of the post already says.
- A station's \`description\` is not its \`situation\` again: the first is the post as
  staff refer to it ("house search for a missing woman with dementia"), the second is
  the scenario as the team meets it. If one would repeat the other, cut the
  description to the line that tells this post apart from the one before it.
- Never put a real person in any field. \`persons\` are fictional scenario subjects, and
  a marker roster or a named contact belongs nowhere in a plan — drop the name, keep the
  role ("markør tildeles av veileder"). An operational *value* is different and does
  belong: a duty phone number, a KO number, a talegruppe. Declare it as a plan variable
  and write {{var.<slug>}}, never the literal in prose — it is decided late and changed
  on the day, which is exactly what a variable is for. And nothing in a markdown field is
  stripped at publish: not \`director_notes\`, not \`behavior\`, not a station
  \`description\`. Only the Staff layer is private, so anything you write as prose ships
  to the open catalog verbatim.
- An exercise says how its teams relate to its stations with \`mode\`: \`ring\` (the
  default — teams rotate, one per station), \`together\` (all teams on one station at a
  time) or \`split\` (several stations at once, teams divided). Not every exercise is a
  rotation, and forcing one into \`ring\` produces a schedule the reader cannot tell is
  wrong. Never use \`numberOfTeams: 1\` to make an all-together phase come out right —
  that predates modes and makes the brief name the merged group after its first team.
- numberOfTeams must be less than or equal to the number of stations — in a ring
  route. With \`mode: together\` every team works the same station at once, and with
  \`mode: split\` the teams divide between stations that run in parallel, so neither
  is bound by that rule. numberOfRounds is likewise authored only in \`ring\`; the
  others derive it, one round per station or per group.
- A station may carry its own \`executionTime\`, \`evaluationTime\` and
  \`rotationTime\`, overriding the exercise's. Write them where the source document
  states them — "post b takes 100 minutes" is a fact about the post, not about a round
  — and put a long walk on the post it leaves from rather than inflating the exercise's
  \`rotationTime\` for every post. Absent inherits. \`0\` is real for evaluation (no
  debrief) and rotation (next post at the same spot); execution must be at least 1.
- In \`ring\` every station is live every round, so each phase is the longest of that
  phase across all stations — maximised independently, since the post that runs longest
  need not be the one furthest from the next. An override there lengthens the whole
  exercise and leaves the other stations waiting. In \`together\` a round is a station,
  so it takes that station's own three; in \`split\`, the longest in the group.
- \`mode: split\` also takes \`groups\`: one entry per round, naming the stations that
  run at the same time and which teams go to each, by list position. A team in two
  stations of one group is an error — they run at once — and a team in none is a
  warning that \`--strict\` promotes. Keep a concurrent phase in one exercise: split it
  across two and the later stations renumber, losing the codes the source document uses.
- "Equipment" is two fields split by audience: a station's \`equipment\` is
  participant-visible, a roleplay's \`props\` is staff-only. A house to search goes in
  \`equipment\`; anything that *is* the find — a dummy, the rope beside it — goes in
  the marker's \`props\`, or \`director_notes\` where the post has no marker. Backwards
  prints the find in the participant handout. Check with audience=participant.
- A markdown field is visible only to the audiences it declares, so a spoiler is
  withheld only if it sits in the field that owns it: the marker's script in
  \`behavior\`, intel to withhold in \`leader_answers\`.
- Never hand-roll a value the format derives — a round-time table, a phase
  breakdown, a duration, a station code. Those go stale the moment a start time or
  duration changes. Write the token instead: {{exercise.roundTable}},
  {{exercise.phaseBreakdown}}, {{exercise.durationLabel}},
  {{station.stationCode}}, {{station.duration}},
  {{plan.exerciseCount}}, {{plan.teamCount}}, {{plan.stationCount}}. Call
  \`schema\` for the full list. A source document has such values printed because
  paper cannot compute — that does not make them content.
- A literal you write more than a few times wants to be a variable. Nothing derives
  a talegruppe, a duty phone number, a meeting place or a team designation, so no
  token exists for them — declare a plan variable and reference {{var.<slug>}},
  which the author can then edit in one place. Sweep for these once the draft is
  written: promote a literal that appears in three or more fields, or one decided
  late or changed on the day. Do not promote a word that merely recurs in prose.
- A \`variableOverrides\` applies to every field that entity *renders*, not only the
  ones it owns. A station with no \`comms\` shows its exercise's, resolved against the
  station — so a post on its own talegruppe needs the override and nothing else. Never
  write \`{{var.talegruppe}}\` into \`logistics\` to force a per-post value: it resolves,
  and prints the talk group in the administration section instead of Samband.

- Send the whole document in one call. A real plan is 60-90 KB of YAML and the limit
  is 512 KB, so it fits — splitting it, summarising it or sending an excerpt is never
  right, and a truncation warning from your own tooling is not a statement about this
  server. Pass \`cache: true\` on the first call and \`document_hash\` after it, so a
  long document is sent once per session rather than once per call.
- \`build_plan\` answers with a handle in \`archive\`, not with the archive: a \`path\`
  on a local server, a \`url\` on the hosted one. **Tell the author where it is**, and
  that a url expires — the build is worthless to them if the link stays in your head.
  The url is a plain GET returning the file as an attachment, so **fetch it yourself**
  when you need the archive on disk; it is the tool's own answer, not a separate API.
  Reach for \`inline: true\` only when you cannot fetch a url at all — it returns ~100
  KB of base64 you cannot read and that many clients silently truncate, which is the
  reason the handle exists, but an unreachable handle is worse than large bytes.

Order of work: schema, create_plan, then read a published plan with get_plan, write,
analyze_plan and fix everything it reports, render_plan and actually read it, then
build_plan. Scaffold *before* reading the catalog, and take structure from the
scaffold: it demonstrates the current format, while a published plan can be older
than the format and is worth reading for scope and prose rather than as a template.
Run analyze_plan before calling a document finished — tokens are stored raw, so a bad
reference is invisible until a reader is holding the brief, and its suggestions are
where a plan that merely transcribes its source differs from one an author can edit.

The full conventions ship as the ringdrill-plan-authoring skill.`;

/// What `initialize` reports.
export const SERVER_INFO = { name: 'ringdrill', version: '1.0.0' };

/// The authoring guide, exposed as MCP resources (ADR-0065).
///
/// Served from the skill's own markdown so there is one source: a convention cannot
/// be right in the skill and stale in the server. `instructions` carries the rules
/// that must be seen; these carry the reasoning, which is far too long to put in
/// front of every request — and a resource is fetched once per session rather than
/// pasted per call, so it does not reintroduce ADR-0064's problem.
///
/// `file` is repo-relative. Resolving it is the transport's job: the stdio server
/// reads from the checkout, the hosted one from files bundled with the function.
export const RESOURCES = [
    {
        uri: 'ringdrill://guide/authoring',
        name: 'Authoring a RingDrill plan',
        description:
            'The conventions the schema cannot express: what to write, in what ' +
            'order, and the mistakes that build cleanly and then read badly. ' +
            'Read this before writing a plan.',
        mimeType: 'text/markdown',
        file: 'skills/ringdrill-plan-authoring/SKILL.md',
    },
    {
        uri: 'ringdrill://guide/format',
        name: 'The source format — vocabulary and shape',
        description:
            'What the entities mean and why the shape is what it is: the ' +
            'rotation and what it cannot express, every markdown field and which ' +
            'audiences see it, the token grammar, coordinates.',
        mimeType: 'text/markdown',
        file: 'skills/ringdrill-plan-authoring/reference/format.md',
    },
];

/// The workflow, offered as a prompt for clients that surface them (ADR-0065).
///
/// A convenience, not a guarantee: a prompt is user-triggered, so an agent that
/// never lists them loses nothing it had. Self-contained rather than reading the
/// guide, so it behaves the same on a transport whose resources are unavailable.
export const PROMPTS = [
    {
        name: 'author_plan',
        description:
            'Draft or extend a RingDrill drill plan, in the order that works and ' +
            'with the rules that are not in the schema.',
        arguments: [
            {
                name: 'brief',
                description:
                    'What the exercise should train, and anything already ' +
                    'decided — audience, duration, terrain, how many teams.',
                required: false,
            },
        ],
    },
];

/// The message body for [PROMPTS]'s `author_plan`.
export function authorPlanPrompt(brief) {
    return (
        `${INSTRUCTIONS}\n\n` +
        'Read ringdrill://guide/authoring and ringdrill://guide/format first if ' +
        'this client can read resources; they carry the reasoning behind the ' +
        'rules above.\n\n' +
        'Then: call schema, read one published plan with search_catalog and ' +
        'get_plan to see how much prose a station really carries, scaffold with ' +
        'create_plan, write the content, and run analyze_plan until it is clean. ' +
        'Render the brief and read it — a plan can be structurally perfect and ' +
        'train nothing. Build only when it is right.\n\n' +
        (brief
            ? `What this plan is for:\n${brief}`
            : 'Ask what the exercise is for before inventing learning goals.')
    );
}

/// Handles one JSON-RPC message against [tools], returning the response object —
/// or null for a notification, which takes no reply.
///
/// Transport-agnostic on purpose: the stdio server writes the result as a line,
/// the Netlify function as a response body, and neither needs to know how the
/// other frames it. That is what keeps `initialize`/`tools/list`/`tools/call`
/// behaving identically whichever way a client reaches us.
export async function handleMessage(message, tools, { readResource } = {}) {
    const { id, method, params } = message;
    if (id === undefined || id === null) return null;

    const reply = (result) => ({ jsonrpc: '2.0', id, result });
    const fail = (code, msg) => ({
        jsonrpc: '2.0',
        id,
        error: { code, message: msg },
    });

    switch (method) {
        case 'initialize':
            return reply({
                protocolVersion: PROTOCOL_VERSION,
                // Resources only when the transport can actually read them: a
                // capability advertised and then failing is worse than one absent.
                capabilities: {
                    tools: {},
                    prompts: {},
                    ...(readResource ? { resources: {} } : {}),
                },
                serverInfo: SERVER_INFO,
                instructions: INSTRUCTIONS,
            });

        case 'resources/list':
            return reply({
                resources: RESOURCES.map(
                    ({ uri, name, description, mimeType }) => ({
                        uri,
                        name,
                        description,
                        mimeType,
                    }),
                ),
            });

        case 'resources/read': {
            const uri = params?.uri;
            const resource = RESOURCES.find((r) => r.uri === uri);
            if (!resource) {
                return fail(
                    -32602,
                    `Unknown resource "${uri}". Have: ` +
                        `${RESOURCES.map((r) => r.uri).join(', ')}.`,
                );
            }
            if (!readResource) {
                return fail(-32603, 'This server cannot read resources.');
            }
            try {
                const text = await readResource(resource);
                return reply({
                    contents: [
                        { uri, mimeType: resource.mimeType, text },
                    ],
                });
            } catch (e) {
                return fail(-32603, `Cannot read ${uri}: ${e.message}`);
            }
        }

        case 'prompts/list':
            return reply({ prompts: PROMPTS });

        case 'prompts/get': {
            const name = params?.name;
            if (!PROMPTS.some((p) => p.name === name)) {
                return fail(
                    -32602,
                    `Unknown prompt "${name}". Have: ` +
                        `${PROMPTS.map((p) => p.name).join(', ')}.`,
                );
            }
            return reply({
                description: PROMPTS[0].description,
                messages: [
                    {
                        role: 'user',
                        content: {
                            type: 'text',
                            text: authorPlanPrompt(params?.arguments?.brief),
                        },
                    },
                ],
            });
        }

        case 'tools/list':
            return reply({
                tools: tools.map(({ name, description, inputSchema }) => ({
                    name,
                    description,
                    inputSchema,
                })),
            });

        case 'tools/call': {
            const tool = tools.find((t) => t.name === params?.name);
            if (!tool) {
                return fail(
                    -32602,
                    `Unknown tool "${params?.name}". Have: ` +
                        `${tools.map((t) => t.name).join(', ')}.`,
                );
            }
            try {
                const result = await tool.run(params.arguments ?? {});
                return reply({
                    content: [
                        { type: 'text', text: JSON.stringify(result, null, 2) },
                    ],
                    // Diagnostics are a result, not a failure — but flag one that
                    // did not pass, so a rejection is not read as a success.
                    isError: result?.ok === false,
                });
            } catch (e) {
                // Reported as tool content rather than a protocol error so the
                // agent can react to it — fix the document, install the CLI —
                // instead of only seeing the call fail.
                return reply({
                    content: [{ type: 'text', text: String(e?.message ?? e) }],
                    isError: true,
                });
            }
        }

        case 'ping':
            return reply({});

        default:
            return fail(-32601, `Method not found: ${method}`);
    }
}
