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
//   create(args)                    -> {document}
//   analyze({document|document_path, strict})  -> {ok, errors, warnings, …}
//   build({document|document_path, strict})    -> {ok, contentHash, drillBase64, …}
//   render({document|document_path, audience, lang, exercise, station, format})
//                                              -> {markdown, …}
//   searchCatalog({limit, cursor})  -> {items, nextCursor?}
//   getPlan({slug, version})        -> {document, …}
//
// Deliberately no Node built-ins here: this module is imported by a Netlify
// function, so it stays plain data plus calls into the injected backend.

/** Shared argument description, so the two document-taking tools agree. */
const SOURCE_DOCUMENT_ARG = {
    type: 'string',
    description:
        'The source document, as YAML text. Call `schema` for its shape, or ' +
        '`create_plan` for a starting point.',
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
                'List published plans in the open catalog, with their tags. The ' +
                'catalog is the corpus: read a few plans with `get_plan` before ' +
                'writing one, so a generated plan matches how real ones are ' +
                'written.',
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
                '— the same format you write, not the raw archive. This is how to ' +
                'read the corpus: the uuids it carries mean an edited copy ' +
                'rebuilds onto the same plan rather than a duplicate.',
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
            run: (args) => backend.create(args),
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
                'the brief.',
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
            run: (args) => backend.analyze(args),
        },
        {
            name: 'build_plan',
            description:
                'Compile a source document to a .drill archive and return it ' +
                'base64-encoded, plus the plan summary and content hash. Does not ' +
                'publish: the catalog is a shared corpus, so putting a plan in it ' +
                'stays a human step.',
            inputSchema: {
                type: 'object',
                properties: {
                    document: SOURCE_DOCUMENT_ARG,
                    document_path: SOURCE_DOCUMENT_PATH_ARG,
                    document_hash: DOCUMENT_HASH_ARG,
                    cache: CACHE_ARG,
                    strict: {
                        type: 'boolean',
                        description: 'Refuse to build if there are warnings.',
                    },
                },
                anyOf: DOCUMENT_OR_PATH,
            },
            run: (args) => backend.build(args),
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
            run: (args) => backend.render(args),
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
- Never put a real person in any field. \`persons\` are fictional scenario subjects,
  and \`director_notes\` is NOT stripped at publish — a marker roster or a duty
  phone number there ships to the public catalog.
- numberOfTeams must be less than or equal to the number of stations.
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

Order of work: schema, read a published plan with get_plan, create_plan, write,
analyze_plan and fix everything it reports, render_plan and actually read it, then
build_plan. Run analyze_plan before calling a document finished — tokens are stored
raw, so a bad reference is invisible until a reader is holding the brief.

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
