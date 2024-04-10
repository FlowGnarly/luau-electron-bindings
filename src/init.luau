-- this module could either be required for only creating elements
-- or it could be required for hosting a server and creating elements
local app = require('./bindings/app')
local ipc = require('./bindings/ipc')
local promise = require('./bindings/promise')
local server = require('./bindings/server')

export type Event = app.Event
export type HTMLElement = app.HTMLElement
export type Promise<T...> = promise.Promise<T...>

return {
    app = app,
    promise = promise,
    server = server,
    ipc = ipc,
}
