/* tslint:disable */
/* eslint-disable */

/**
 * Called once from JS to set up panic hook and tracing.
 * The WASM module is loaded eagerly but the app is NOT started until `start()`.
 */
export function init_runtime(): void;

/**
 * Start the egui app. Called from JS after the user clicks Connect.
 */
export function start(): void;

export type InitInput = RequestInfo | URL | Response | BufferSource | WebAssembly.Module;

export interface InitOutput {
    readonly memory: WebAssembly.Memory;
    readonly init_runtime: () => void;
    readonly start: () => void;
    readonly wasm_bindgen__closure__destroy__h3452b58355cea29b: (a: number, b: number) => void;
    readonly wasm_bindgen__closure__destroy__h0f7de56ebf380701: (a: number, b: number) => void;
    readonly wasm_bindgen__closure__destroy__hc26fc3b7e3374af1: (a: number, b: number) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h12e2ea7034124d37: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h1b4fbeb7996b3875: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h5f8d8aab6f51d912: (a: number, b: number) => [number, number];
    readonly wasm_bindgen__convert__closures_____invoke__h4e7ff8cd50b2bc55: (a: number, b: number, c: any) => void;
    readonly __wbindgen_malloc: (a: number, b: number) => number;
    readonly __wbindgen_realloc: (a: number, b: number, c: number, d: number) => number;
    readonly __externref_table_alloc: () => number;
    readonly __wbindgen_externrefs: WebAssembly.Table;
    readonly __wbindgen_exn_store: (a: number) => void;
    readonly __wbindgen_free: (a: number, b: number, c: number) => void;
    readonly __externref_table_dealloc: (a: number) => void;
    readonly __wbindgen_start: () => void;
}

export type SyncInitInput = BufferSource | WebAssembly.Module;

/**
 * Instantiates the given `module`, which can either be bytes or
 * a precompiled `WebAssembly.Module`.
 *
 * @param {{ module: SyncInitInput }} module - Passing `SyncInitInput` directly is deprecated.
 *
 * @returns {InitOutput}
 */
export function initSync(module: { module: SyncInitInput } | SyncInitInput): InitOutput;

/**
 * If `module_or_path` is {RequestInfo} or {URL}, makes a request and
 * for everything else, calls `WebAssembly.instantiate` directly.
 *
 * @param {{ module_or_path: InitInput | Promise<InitInput> }} module_or_path - Passing `InitInput` directly is deprecated.
 *
 * @returns {Promise<InitOutput>}
 */
export default function __wbg_init (module_or_path?: { module_or_path: InitInput | Promise<InitInput> } | InitInput | Promise<InitInput>): Promise<InitOutput>;
