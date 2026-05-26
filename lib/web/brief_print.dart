/// Stub for non-web platforms. The brief print button calls into this
/// surface; on native it is a no-op because system-level print is not
/// part of v1 (DESIGN-004 Stage 5 covers the web print stylesheet; a
/// native PDF export is explicitly deferred).
void printBrief() {}
