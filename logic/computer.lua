require("logic.util")

if not global.computerGuis then global.computerGuis = {} end
if not global.computers then global.computers = {} end
if not global.waypoints then global.waypoints = {} end

computer = {
    apis = {},

    commands = {},

    guis = {},

    _mt = {
        __eq = function(a, b)
            return a.data == b.data
        end
    },

    new = function(entity)
        local obj = {
            valid = true,

            data = nil,
            gui = nil,
            history = ""
        }

        for index, value in pairs(computer) do
            if index ~= "_mt" then
                obj[index] = value
            else
                setmetatable(obj, value)
            end
        end

        local index
        if entity.type == "player" then
            for i, computer in pairs(global.computers) do
                if computer.entityIsPlayer and computer.entityIsPlayer == entity.player.index then
                    index = i
                end
            end
        else
            index = searchIndexInTable(global.computers, entity, "entity")
        end
        if index then
            obj.data = global.computers[index]
            if not obj.data.entity or not obj.data.entity.valid then
                if obj.data.entityIsPlayer then
                    obj.data.entity = entity
                else
                    global.computers[index] = nil
                    return nil
                end
            end
        else
            obj.data = {
                entity = entity,
                entityIsPlayer = nil,

                label = nil,

                player = nil,
                output = "",
                process = nil,

                events = {},
                apis = {},
                env = {},

                root = {
                    type = "dir",

                    parent = nil,

                    ctime = game.tick,
                    mtime = game.tick,
                    atime = game.tick,

                    files = {}
                },
            }
            if entity.type == "player" then
                obj.data.entityIsPlayer = entity.player.index
            end
            obj.data.root.parent = obj.data.root
            obj.data.cwd = obj.data.root

            if not global.computers then global.computers = {} end
            table.insert(global.computers, obj.data)
        end

        obj.history = computer.commands.pwd[2](obj, obj.data) .. "> "

        return obj
    end,

    load = function(data)
        if not data.entity or not data.entity.valid then
            return nil
        end

        local obj = {
            valid = true,

            data = data,
            gui = nil,
            history = ""
        }

        for index, value in pairs(computer) do
            if index ~= "_mt" then
                obj[index] = value
            else
                setmetatable(obj, value)
            end
        end

        obj.history = computer.commands.pwd[2](obj, obj.data) .. "> "

        return obj
    end,

    getPlayer = function(self)
        if self.data.player then
            return game.players[self.data.player]
        else
            return nil
        end
    end,

    setPlayer = function(self, player)
        if player ~= nil then
            self.data.player = player.index
        else
            self.data.player = nil
        end
    end,

    getLabeleld = function(self)
        local player = self:getPlayer()
        local labels = {}

        if player then
            for i, computerData in pairs(global.computers) do
                if not computerData.entityIsPlayer or computerData.entityIsPlayer == player.index then
                    local _computer = computer.load(computerData)
                    if _computer then
                        local computerPlayer = _computer:getPlayer()
                        if computerPlayer and (computerPlayer.force == player.force or computerPlayer.force.get_friend(player.force)) and computerData.label then
                            labels[computerData.label] = _computer
                        end
                    end
                end
            end
        end

        return labels
    end,

    getComputers = function(self, label)
        local player = self:getPlayer()
        local computers = {}

        if player then
            for i, computerData in pairs(global.computers) do
                local _computer = computer.load(computerData)
                if _computer then
                    local computerPlayer = _computer:getPlayer()
                    if computerPlayer and (computerPlayer.force == player.force or computerPlayer.force.get_friend(player.force)) and (not label or computerData.label == label) then
                        table.insert(computers, _computer)
                    end
                end
            end
        end

        return computers
    end,

    registerEmitter = function(self, name, eventEmitter)
        if not self.data.eventEmitters then self.data.eventEmitters = {} end

        table.insert(self.data.eventEmitters, {
            name = name,
            emitter = eventEmitter
        })
    end,

    raise_event = function(self, event_name, process, ...)
        if self.data.entity.electric_buffer_size and self.data.entity.energy == 0 then
            return
        end

        for index, eventEmitter in pairs(self.data.eventEmitters or {}) do
            if eventEmitter.name == event_name then
                eventEmitter.emitter:emit(process, ...)
            end
        end
    end,

    clearEmitters = function(self)
        self.data.eventEmitters = {}
    end,

    loadAPI = function(self, api, item, proxy, env)
        local player = self:getPlayer()
        setmetatable(item, {
            -- protected metatable
            __index = setmetatable({
                -- Empty object (this is a proxy to the private properties of the API)
            }, {
                -- private properties
                env = env,
                computer = self,
                player = player,

                getters = {
                    __getAPI = function(self, name)
                        return self.env.proxies[name]
                    end,
                    __getOutput = function(self)
                        return self.computer.data.output
                    end,
                    __setOutput = function(self, text)
                        self.computer.data.output = text
                        local gui = searchInTable(global.computerGuis, self.computer.data, "os", "data")
                        if gui and gui.print then
                            gui:print(self.computer.data.output)
                        end
                    end,
                    __getLabel = function(self)
                        return self.computer.data.label
                    end,
                    __setLabel = function(self, label)
                        self.computer.data.label = label
                    end,
                    __getID = function(self)
                        return table.id(self.computer.data)
                    end,
                    __emit = function(self, label, event_name, ...)
                        for index, computer in pairs(self.computer:getComputers(label)) do
                            if computer.data and computer.data.process then
                                computer:raise_event(event_name, computer.data.process, ...)
                            end
                        end
                    end,
                    __broadcast = function(self, event_name, ...)
                        for index, computer in pairs(self.computer:getComputers()) do
                            if computer.data and computer.data.process then
                                computer:raise_event(event_name, computer.data.process, ...)
                            end
                        end
                    end,
                    __getWaypoint = function(self, name)
                        if not global.waypoints then
                            global.waypoints = {}
                        end
                        for index, waypoint in pairs(global.waypoints) do
                            if waypoint.force == self.player.force and waypoint.name == name then
                                return waypoint
                            end
                        end
                        return nil
                    end,
                    __getGameTick = function()
                        return game.tick
                    end,
                    __require = function(self, filename)
                        local file = self.env.file.parent

                        assert(type(filename) == "string")
                        assert(filename ~= ".")
                        assert(filename ~= "..")

                        if filename:startsWith("/") then
                            file = self.computer.data.root
                        end

                        for index, _dirname in pairs(filename:split("/")) do
                            if _dirname ~= "" then
                                assert(file.type == "dir", filename .. " isn't a directory")
                                assert(file.files[_dirname] ~= nil, filename .. " no such file or directory")
                                file = file.files[_dirname]
                            end
                        end
                        assert(file.type == "file", filename .. " isn't a file")

                        game.print(table.tostring(self.env.filesLoaded))
                        for index, lib in ipairs(self.env.filesLoaded) do
                            if lib.file == file then
                                return lib.result
                            end
                        end
                        file.atime = game.tick;

                        local fct, err = load(file.text, nil, "t", self.env.proxies)
                        assert(err == nil, err)
                        local success, result = pcall(fct)
                        assert(success == true, result)

                        table.insert(self.env.filesLoaded, {file = file, result = result})
                        return result
                    end
                },

                -- access to private properties
                __index = function(table, key)
                    local self = getmetatable(table)
                    if type(self.getters[key]) == "function" then
                        return function(...)
                            return self.getters[key](self, ...)
                        end
                    end
                    return self.getters[key]
                end,

                -- Set protected metatable 'Read-Only'
                __newindex = function(self, key)
                    assert(false, "Can't edit protected metatable")
                end
            }),

            -- The API isn't 'Read-Only'

            -- Protect metatable (blocks access to the metatable)
            __metatable = "this is the protected API " .. api.name
        })

        setmetatable(proxy, {
            -- protected metatable
            __index = setmetatable({
                -- Empty object (this is a proxy to the private properties of the proxy)
            }, {
                -- private properties
                env = env,
                api = item,
                apiPrototype = api,

                -- access to private properties
                __index = function(tbl, key)
                    local self = getmetatable(tbl)
                    assert(self.env.prototypes[self.apiPrototype.name][key], self.apiPrototype.name .. " doesn't have key " .. key)
                    if type(self.api[key]) == "function" then
                        return function(...)
                            return self.api[key](self.api, ...)
                        end
                    end
                    return self.api[key]
                end,

                -- Set protected metatable 'Read-Only'
                __newindex = function(self, key)
                    assert(false, "Can't edit protected metatable")
                end
            }),

            -- Set Proxy 'Read-Only'
            __newindex = function(self, key)
                assert(false, "Can't edit API " .. self.apiPrototype.name)
            end,

            -- Protect metatable (blocks access to the metatable)
            __metatable = "this is the API " .. api.name
        })

        return item, proxy
    end,

    openGui = function(self, type, player)
        if not global.computerGuis then global.computerGuis = {} end
        if self.data.output ~= "" then
            type = "output"
        end
        assert(computer.guis[type] ~= nil)

        local curentPlayer = self:getPlayer()
        if not player then
            player = curentPlayer
        end

        if curentPlayer and curentPlayer ~= player then
            if global.computerGuis[curentPlayer.index] and global.computerGuis[curentPlayer.index].os == self then
                player.print("Another player is already connected to this computer")
                return nil
            elseif self:getPlayer().force ~= player.force and not self:getPlayer().force.get_friend(player.force) then
                player.print("Can't connect to a computer of an enemy force")
                return nil
            end
        end

        self:closeGui()
        self:setPlayer(player)

        self.gui = computer.guis[type].new(player, self)
        if type == "output" then
            self.gui.file = self.data.file
        end
        global.computerGuis[player.index] = self.gui;
        return self.gui
    end,

    closeGui = function(self)
        local player = self:getPlayer()
        local gui

        if self.gui then
            gui = self.gui
        elseif player then
            gui = global.computerGuis[player.index]
        end

        if gui then
            gui:destroy()
            if player then
                global.computerGuis[player.index] = nil
            end
        end
    end,

    exec = function(self, text, ...)
        text = text:trim()
        if text ~= "" then
            local params = text:split("%s", nil, true)
            local command = computer.commands[params[1]]

            if command == nil then
                return "Unknown command '" .. text .. "'\n"
            else
                table.remove(params, 1)

                for index, value in pairs({...}) do
                    table.insert(params, value)
                end
                return command[2](self, self.data, unpack(params))
            end
        end
    end,

    destroy = function(self)
        self.valid = false

        table.remove(global.computers, searchIndexInTable(global.computers, self.data.entity, "entity"))
    end
}

remote.add_interface("computer_core", {
    addComputerAPI = function(api)
        if type(api) == "string" then
            local construct, err = load(api, nil, "t", deepcopy(baseEnv, {
                debug = function(text)
                    if type(text) == "string" then
                        game.print("Debug: " .. text)
                    elseif type(text) == "table" then
                        game.print("Debug: " .. tostring(text) .. "\n" .. table.tostring(text))
                    else
                        game.print("Debug: " .. tostring(text))
                    end
                end,
                remote = remote
            }))
            assert(err == nil, err)
            local success, obj = pcall(construct)
            assert(success, obj)
            api = obj
        end
        table.insert(computer.apis, api)
    end,
    addEntityStructure = function(struct)
        table.insert(global.structures, struct)
    end
})