local APP = require('./bindings/app')
local promise = require('./bindings/promise')

export type HTMLElement = APP.HTMLElement
export type Promise<T...> = promise.Promise<T...>

return function(port: number)
    local modules = {
        app = APP(port),
        promise = promise,
    }

    return modules
end
