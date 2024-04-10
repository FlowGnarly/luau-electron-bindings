local server = require('server')

type HTMLElementRequested = {
    selector: string?,
    tagName: string?,
    id: number,
}

type Property = { [string]: Property | any }

-- TODO: types are incomplete so finish them later please :)
export type Event = {
    eventName: string,
    altKey: boolean,
    bubbles: boolean,
    button: number,
    buttons: number,
    cancelBubble: boolean,
    cancelable: boolean,
    clientX: number,
    clientY: number,
    composed: boolean,
    ctrlKey: boolean,
    currentTarget: unknown,
    defaultPrevented: boolean,
    detail: number,
    eventPhase: number,
    fromElement: unknown,
    isTrusted: boolean,
    layerX: number,
    layerY: number,
    metaKey: boolean,
    movementX: number,
    movementY: number,
    offsetX: number,
    offsetY: number,
    pageX: number,
    pageY: number,
    path: unknown,
    relatedTarget: unknown,
    returnValue: unknown,
    screenX: number,
    screenY: number,
    shiftKey: boolean,
    sourceCapabilities: unknown,
    target: unknown,
    timeStamp: number,
    toElement: unknown,
    view: unknown,
    which: number,
    x: number,
    y: number,
}

export type HTMLElement = {
    id: number,
    set_prop: (property: string, value: any) -> (),
    set_props: (self: HTMLElement, properties: { [string]: Property | any }) -> (),
    set_event: (event: string, callback: (event: Event) -> ()) -> () -> (),
    [string]: any,
}

local ipc = require('./ipc')
local promise = require('promise')
local task = require('@lune/task')

local on_load_listeners: { (document: Document) -> () } = {}
local app = {}
app.reserved_id = 1
app.reserved_event_id = 1

local function is_table_a_html_element(element: any): boolean
    if element.is_element then
        return true
    end

    return false
end

local function create_html_element_from_id(id: number): HTMLElement
    local t: HTMLElement = {
        id = id,
        set_prop = function(k, v: HTMLElement | string | number)
            if typeof(v) == 'table' and is_table_a_html_element(v) then
                v = v.id
            end

            ipc.send({
                type = 'Method',
                method = 'setProperty',
                headers = {
                    id = id,
                    k = k,
                    v = v,
                },
            })
        end,
        set_props = function(self, props: { [string]: Property })
            for k, v in props do
                if typeof(v) == 'table' then
                    if is_table_a_html_element(v) then
                        self.set_prop(k, v)
                    else
                        task.defer(function()
                            ipc.send({
                                type = 'Method',
                                method = 'setNestedProperties',
                                headers = {
                                    id = id,
                                    k = k,
                                    v = v,
                                },
                            })
                        end)
                    end
                else
                    self.set_prop(k, v)
                end
            end
        end,
        set_event = function(event: string, callback: (event: Event) -> ())
            local event_id = app.reserved_event_id
            app.reserved_event_id += 1

            ipc.send({
                type = 'Method',
                method = 'setEvent',
                headers = {
                    id = id,
                    event = event,
                    eventId = event_id,
                },
            })

            local disconnect = ipc.on('event:' .. event_id, callback)

            return function()
                ipc.send({
                    type = 'Method',
                    method = 'disconnectEvent',
                    headers = {
                        id = id,
                        event = event,
                        eventId = event_id,
                    },
                })

                disconnect()
            end
        end,
    }

    local mt = {
        __index = function(_, i)
            if i == 'is_element' then
                return true
            end

            if rawget(t, i) then
                return rawget(t, i)
            else
                error('__index is not implemented yet.')
            end
        end,
        __newindex = function(_, i, v)
            if v == nil then
                if i == 'parent' then
                    t.set_prop(i, 'null')
                else
                    error(`Not allowed to set {i} to nil.`)
                end
            else
                t.set_prop(i, v)
            end
        end,
    }

    return setmetatable({}, mt) :: any
end

type Document = {
    query_selector: (selector: string) -> promise.Promise<HTMLElement>,
    create_element: (tag_name: string, inner_html: string?) -> promise.Promise<HTMLElement>,
}

app.document = {}

app.document.query_selector = function(selector: string): promise.Promise<HTMLElement>
    ipc.send({
        type = 'Method',
        method = 'querySelector',
        headers = {
            selector = selector,
        },
    })

    return promise.new(function(res)
        ipc.invoke('querySelector', {
            selector = selector,
        }).andThen(function(info: HTMLElementRequested)
            app.reserved_id = info.id
            res(create_html_element_from_id(info.id))
        end)
    end)
end

app.document.create_element = function(
    tag_name: string,
    inner_html: string?
): promise.Promise<HTMLElement>
    return promise.new(function(res)
        ipc.invoke('createElement', {
            tagName = tag_name,
            innerHTML = inner_html,
        }).andThen(function(info: HTMLElementRequested)
            res(create_html_element_from_id(info.id))
        end)
    end)
end

server.load = function()
    app.reserved_id = 1
    app.reserved_event_id = 1
    ipc.invoke_reserved_id = 1

    for channel, listener in server.listeners do
        server.listeners[channel] = nil
    end

    for _, callback in on_load_listeners do
        callback(app.document)
    end
end

app.on_load = function(callback: (document: Document) -> ())
    table.insert(on_load_listeners, callback)
end

return app
