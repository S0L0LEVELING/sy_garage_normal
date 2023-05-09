lib.locale()


lib.callback.register('sy_garage:getOwnerVehicles', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    local identifier = xPlayer.getIdentifier()
    local vehicles = {}
    
    local results = MySQL.Sync.fetchAll(
        "SELECT * FROM `owned_vehicles` WHERE `owner` = @identifier OR `amigos` LIKE @like_identifier", {
            ['@identifier'] = identifier,
            ['@like_identifier'] = '%' .. identifier .. '%',
        })
    
    if results[1] ~= nil then
        for i = 1, #results do
            local result = results[i]
            local veh = json.decode(result.vehicle)
            veh.plate = result.plate
            veh.parking = result.parking
            veh.stored = result.stored
            veh.pound = result.pound
            veh.mileage = result.mileage
            veh.type = result.type
            veh.id = identifier
            veh.duen = result.owner
            veh.amigos = result.amigos
            veh.props = result.vehicle
            
            local isFriend = false
            if amigos ~= nil then
                for j = 1, #amigos do
                    local amigo = amigos[j]
                    if amigo == identifier then
                        isFriend = true
                        break
                    end
                end
            end
            if result.owner == identifier or isFriend then
                veh.owned = true
                vehicles[#vehicles + 1] = veh
            end
        end
    end
    
    local sharedResults = MySQL.Sync.fetchAll(
        "SELECT * FROM `owned_vehicles` WHERE JSON_CONTAINS(`amigos`, @identifier, '$')", {
            ['@identifier'] = json.encode({identifier = identifier}),
        })
    
    if sharedResults[1] ~= nil then
        for i = 1, #sharedResults do
            local result = sharedResults[i]
            local veh = json.decode(result.vehicle)
            veh.plate = result.plate
            veh.parking = result.parking
            veh.stored = result.stored
            veh.pound = result.pound
            veh.mileage = result.mileage
            veh.type = result.type
            veh.id = identifier
            veh.duen = result.owner
            veh.amigos = json.decode(result.amigos)
            veh.props = result.vehicle
            --AGregar vehiculo si esta compartido a la lista.
            if result.owner ~= identifier then
                veh.owned = false
                vehicles[#vehicles + 1] = veh
            end
        end
    end
    
    
    
    return vehicles
end)


lib.callback.register('sy_garage:owner_vehicles', function(source)
    local vehicles = {}
    local results = MySQL.Sync.fetchAll("SELECT * FROM `owned_vehicles`")
    if results[1] ~= nil then
        for i = 1, #results do
            local result = results[i]
            local veh = json.decode(result.vehicle)
            
            veh.plate = result.plate
            veh.parking = result.parking
            veh.stored = result.stored
            veh.pound = result.pound
            veh.mileage = result.mileage
            veh.type = result.type
            veh.owner = result.owner
            veh.vehicle = result.vehicle
            veh.lastposition = result.lastposition
            vehicles[#vehicles + 1] = veh
            
            if Garage.Debug then
                print('Matrícula:', veh.plate, 'Modelo:', veh.model, 'positiom: ', veh.lastposition)
            end
        end
        
        return vehicles
    end
end)

RegisterServerEvent('sy_garage:EliminarAmigo', function(Amigo, plate)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    local xIndidentifier = xPlayer.getIdentifier()
    MySQL.Async.fetchAll(
        "SELECT `amigos` FROM `owned_vehicles` WHERE `owner` = @identifier AND `plate` = @plate", {
            ['@identifier'] = xIndidentifier,
            ['@plate'] = plate
        }, function(result)
            if result[1] ~= nil then
                local amigosTable = {}
                if result[1].amigos ~= nil and result[1].amigos ~= '' then
                    amigosTable = json.decode(result[1].amigos)
                end
                local found = false
                for i, amigo in ipairs(amigosTable) do
                    if amigo.name == Amigo then
                        table.remove(amigosTable, i)
                        found = true
                        break
                    end
                end
                if found then
                    local amigosStr = json.encode(amigosTable)
                    
                    if #amigosTable == 0 then
                        amigosStr = nil
                    end
                    
                    MySQL.Async.execute(
                        "UPDATE `owned_vehicles` SET `amigos` = @amigos WHERE `owner` = @identifier AND `plate` = @plate",
                        {
                            ['@identifier'] = xIndidentifier,
                            ['@plate'] = plate,
                            ['@amigos'] = amigosStr
                        }, function(rowsChanged)
                            if rowsChanged > 0 then
                                TriggerClientEvent('sy_garage:Notification', source,
                                    locale('AmigosLista1', Amigo, plate))
                            else
                                TriggerClientEvent('sy_garage:Notification', source,
                                    locale('AmigosLista2', Amigo, plate))
                            end
                        end)
                else
                    if Garage.Debug then
                        print('No se encontró al amigo ' .. Amigo .. ' en el vehículo con la matricula ' .. plate)
                    end
                end
            else
                if Garage.Debug then
                    print('No se pudo encontrar el vehículo con la matricula ' .. plate)
                end
            end
        end)
end)




RegisterServerEvent('sy_garage:CompartirAmigo', function(Amigo, Name, plate)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    local xIndidentifier = xPlayer.getIdentifier()
    
    local xAmigo = ESX.GetPlayerFromId(Amigo)
    local identifier = xAmigo.getIdentifier()
    
    if identifier == xIndidentifier then
        TriggerClientEvent('sy_garage:Notification', source, locale('noatimismo'))
        return
    end
    
    MySQL.Async.fetchAll(
        "SELECT `amigos` FROM `owned_vehicles` WHERE `owner` = @identifier AND `plate` = @plate", {
            ['@identifier'] = xIndidentifier,
            ['@plate'] = plate
        }, function(result)
            if result[1] ~= nil then
                local amigosTable = {}
                if result[1].amigos ~= nil and result[1].amigos ~= '' then
                    amigosTable = json.decode(result[1].amigos)
                end
                local amigoData = {name = Name, identifier = identifier}
                amigosTable[#amigosTable + 1] = amigoData
                local amigosStr = json.encode(amigosTable)
                
                
                MySQL.Async.execute(
                    "UPDATE `owned_vehicles` SET `amigos` = @amigos WHERE `owner` = @identifier AND `plate` = @plate",
                    {
                        ['@identifier'] = xIndidentifier,
                        ['@plate'] = plate,
                        ['@amigos'] = amigosStr
                    }, function(rowsChanged)
                        if rowsChanged > 0 then
                            TriggerClientEvent('sy_garage:Notification', source,
                                locale('AmigosLista3', plate, xAmigo.getName()))
                            TriggerClientEvent('sy_garage:Notification', xAmigo.source, locale('AmigosLista4', plate))
                        else
                            TriggerClientEvent('sy_garage:Notification', source,
                                locale('AmigosLista5', xAmigo.getName()))
                        end
                    end)
            else
                if Garage.Debug then
                    print('No se pudo encontrar el vehículo con la matricula ' .. plate)
                end
            end
        end)
end)


RegisterServerEvent('sy_garage:GuardarVehiculo', function(plate, vehicleData, garageName, vehicle)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    local identifier = xPlayer.getIdentifier()
    local vehicleDataDecoded = json.decode(vehicleData)
    local vehicleDataEncoded = json.encode(vehicleDataDecoded)
    local encontrado = false
    local vehicles = MySQL.Sync.fetchAll("SELECT * FROM `owned_vehicles`")
    for i = 1, #vehicles do
        local data = vehicles[i]
        local stored = data.store
        local parking = garageName
        if stored ~= 1 then
            stored = 1
        end
        local amigos = json.decode(data.amigos) or {}
        
        if plate == string.gsub(data.plate, "^%s*(.-)%s*$", "%1") then
            if data.owner == xPlayer.identifier then -- propiedad
                MySQL.Async.execute(
                    "UPDATE `owned_vehicles` SET `vehicle` = @vehicleData, `stored` = @stored,`pound` = @pound, `calle` = @calle, `parking` = @parking WHERE `owner` = @identifier AND `plate` = @plate",
                    {
                        ['@identifier'] = identifier,
                        ['@vehicleData'] = vehicleDataEncoded,
                        ['@plate'] = plate, --string.gsub(plate, "^%s*(.-)%s*$", "%1")
                        ['@stored'] = stored,
                        ['@parking'] = parking,
                        ['@calle'] = nil,
                        ['@pound'] = nil
                    },
                    function(rowsChanged)
                        if rowsChanged > 0 then
                            local vehicle = NetworkGetEntityFromNetworkId(vehicle)
                            DeleteEntity(vehicle)
                            if Garage.Debug then
                                print('Guardando vehículo con placa ' .. plate .. ' para jugador ' .. identifier)
                            end
                            TriggerClientEvent('sy_garage:Notification', source,
                                locale('SERVER_VehiculoGuardado'))
                        else
                            TriggerClientEvent('sy_garage:Notification', source,
                                locale('SERVER_ErrorGuardad'))
                        end
                    end
                )
                encontrado = true
            else
                for j = 1, #amigos do
                    local amigo = amigos[j]
                    if amigo.identifier == xPlayer.identifier then -- de un amigo.
                        MySQL.Async.execute(
                            "UPDATE `owned_vehicles` SET `vehicle` = @vehicleData, `stored` = @stored, `pound` = @pound, `calle` = @calle,  `parking` = @parking WHERE  `plate` = @plate",
                            {
                                ['@vehicleData'] = vehicleDataEncoded,
                                ['@plate'] = plate, --string.gsub(plate, "^%s*(.-)%s*$", "%1")
                                ['@stored'] = stored,
                                ['@parking'] = parking,
                                ['@calle'] = nil,
                                ['@pound'] = nil
                            },
                            function(rowsChanged)
                                if rowsChanged > 0 then
                                    local vehicle = NetworkGetEntityFromNetworkId(vehicle)
                                    DeleteEntity(vehicle)
                                    if Garage.Debug then
                                        print('Guardando vehículo con placa ' .. plate .. ' para jugador ' .. identifier)
                                    end
                                    TriggerClientEvent('sy_garage:Notification', source,
                                        locale('SERVER_VehiculoGuardado'))
                                else
                                    TriggerClientEvent('sy_garage:Notification', source,
                                        locale('SERVER_ErrorGuardad'))
                                end
                            end
                        )
                        encontrado = true
                        break
                    end
                end
            end
        end
    end
    if not encontrado then
        TriggerClientEvent('sy_garage:Notification', source, locale('NoEsTuyo'))
    end
end)






lib.callback.register('sy_garage:getBankMoney', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    local bank = xPlayer.getAccount("bank")
    local money = xPlayer.getMoney()
    return {bank = bank.money, money = money}
end)


RegisterServerEvent('sy_garage:RetirarVehiculo', function(plate, lastparking, pos, hea, props, model)
    local source = source
    MySQL.Async.execute(
        "UPDATE `owned_vehicles` SET `stored` = 0, `lastparking` = @lastparking WHERE `plate` = @plate",
        {
            ['@lastparking'] = lastparking,
            ['@plate'] = plate,
        }, function(rowsChanged)
            if rowsChanged > 0 then
                ESX.OneSync.SpawnVehicle(model, pos, hea, props, function(NetworkId)
                    Wait(100)
                    local Vehicle = NetworkGetEntityFromNetworkId(NetworkId)
                    
                    while not DoesEntityExist(Vehicle) do
                        
                        Wait(0)
                    
                    end
                    
                    if Garage.SetInToVehicle then
                        TaskWarpPedIntoVehicle(source, Vehicle, -1)
                    end
                
                
                end)
                
                TriggerClientEvent('sy_garage:Notification', source, locale('SERVER_retirar'))
            else
                TriggerClientEvent('sy_garage:Notification', source, locale('SERVER_ErrorRetirar'))
            end
        end)
end)



RegisterServerEvent('sy_garage:RetirarVehiculoImpound', function(plate, money, price, props, pos, hea, model)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    local identifier = xPlayer.getIdentifier()
    local bank = xPlayer.getAccount("bank")
    local price = price
    if money == 'money' then
        if xPlayer.getMoney() >= price then
            MySQL.Async.execute(
                "UPDATE `owned_vehicles` SET `pound` = NULL, `parking` = (SELECT `lastparking` FROM `owned_vehicles` WHERE `owner` = @identifier AND `plate` = @plate), `calle` = @calle WHERE `owner` = @identifier AND `plate` = @plate"
                ,
                {
                    ['@identifier'] = identifier,
                    ['@plate'] = plate,
                    ['@calle'] = 1
                }, function(rowsChanged)
                    if rowsChanged > 0 then
                        ESX.OneSync.SpawnVehicle(model, pos, hea, props, function(NetworkId)
                            Wait(100)
                            local Vehicle = NetworkGetEntityFromNetworkId(NetworkId)
                            
                            while not DoesEntityExist(Vehicle) do
                                
                                Wait(0)
                            
                            end
                            
                            if Garage.SetInToVehicle then
                                TaskWarpPedIntoVehicle(source, Vehicle, -1)
                            end
                        
                        
                        end)
                        xPlayer.removeAccountMoney("money", price)
                        TriggerClientEvent('sy_garage:Notification', source,
                            locale('SERVER_RetirarImpound', price))
                    else
                        TriggerClientEvent('sy_garage:Notification', source,
                            locale('SERVER_RetirarImpoundError'))
                    end
                end)
        else
            TriggerClientEvent('sy_garage:Notification', source,
                locale('SERVER_SinDinero'))
        end
    elseif money == 'bank' then
        if bank.money >= price then
            MySQL.Async.execute(
                "UPDATE `owned_vehicles` SET `pound` = NULL, `parking` = (SELECT `lastparking` FROM `owned_vehicles` WHERE `owner` = @identifier AND `plate` = @plate), `calle` = @calle WHERE `owner` = @identifier AND `plate` = @plate"
                ,
                {
                    ['@identifier'] = identifier,
                    ['@plate'] = plate,
                    ['@calle'] = 1
                }, function(rowsChanged)
                    if rowsChanged > 0 then
                        ESX.OneSync.SpawnVehicle(model, pos, hea, props, function(NetworkId)
                            Wait(100)
                            local Vehicle = NetworkGetEntityFromNetworkId(NetworkId)
                            
                            while not DoesEntityExist(Vehicle) do
                                
                                Wait(0)
                            
                            end
                            
                            if Garage.SetInToVehicle then
                                TaskWarpPedIntoVehicle(source, Vehicle, -1)
                            end
                        
                        end)
                        xPlayer.removeAccountMoney("bank", price)
                        TriggerClientEvent('sy_garage:Notification', source,
                            locale('SERVER_RetirarImpound', price))
                    else
                        TriggerClientEvent('sy_garage:Notification', source,
                            locale('SERVER_RetirarImpoundError'))
                    end
                end)
        else
            TriggerClientEvent('sy_garage:Notification', source,
                locale('SERVER_SinDinero'))
        end
    end
end)

function DeleteVehicleByPlate(plate)
    local vehicles = GetAllVehicles()
    for i = 1, #vehicles, 1 do
        if GetVehicleNumberPlateText(vehicles[i]) == plate or (string.match(GetVehicleNumberPlateText(vehicles[i]), plate:gsub("%s", ".*")) ~= nil) then
            DeleteEntity(vehicles[i])
            return true
        end
    end
    return false
end

RegisterServerEvent('sy_garage:MandarVehiculoImpound', function(plate, impo)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    local identifier = xPlayer.getIdentifier()
    
    MySQL.Async.execute(
        "UPDATE `owned_vehicles` SET `parking` = @impo, `pound` = 1 WHERE `owner` = @identifier AND `plate` = @plate",
        {
            ['@identifier'] = identifier,
            ['@plate'] = plate,
            ['@impo'] = impo,
        }, function(rowsChanged)
            if rowsChanged > 0 then
                DeleteVehicleByPlate(plate)
                TriggerClientEvent('sy_garage:Notification', source, locale('SERVER_MandarVehiculoImpound'))
            else
                TriggerClientEvent('sy_garage:Notification', source, locale('SERVER_MandarMal'))
            end
        end)
end)

RegisterServerEvent('sy_garage:AgregarKilometros', function(vehPlate, km)
    local plate = vehPlate
    local newKM = km
    
    MySQL.Async.fetchScalar('SELECT plate FROM owned_vehicles WHERE plate = @plate', {['@plate'] = plate},
        function(result)
            MySQL.Async.execute('UPDATE owned_vehicles SET mileage = @kms WHERE plate = @plate',
                {['@plate'] = plate, ['@kms'] = newKM})
        end)
end)


lib.addCommand(Garage.OwnerCarAdmin.Command, {
    help = locale('setearcar2'),
    restricted = Garage.OwnerCarAdmin.Group,
    params = {
        {
            name = 'target',
            type = 'playerId',
            help = 'Target player\'s server id',
        },
    },
}, function(source, args)
    TriggerClientEvent('sy_garage:CheckVeh2', args.target)
end)



RegisterNetEvent('sy_garage:SetCarDB', function(vehicleData, plate)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer.getGroup() == Garage.OwnerCarAdmin.Group then
        local plate = plate
        local results = MySQL.Sync.fetchAll(
            "SELECT * FROM owned_vehicles WHERE plate = @plate",
            {['@plate'] = plate})
        if results[1] ~= nil then

            TriggerClientEvent('sy_garage:Notification', source,
                'El vehículo con placa ' .. plate .. ' ya está en propiedad.')

            if Garage.Debug then
                print('El vehículo con placa ' .. plate .. ' ya está en propiedad.')
            end
        else
            vehicleData.plate = plate
            local jsonVehicleData = json.encode(vehicleData)
            MySQL.Sync.execute(
                "INSERT INTO owned_vehicles (owner, plate, vehicle, calle) VALUES (@owner, @plate, @vehicle, @calle)",
                {
                    ['@owner'] = xPlayer.identifier,
                    ['@plate'] = plate,
                    ['@vehicle'] = jsonVehicleData,
                    ['@calle'] = nil,
                })
            TriggerClientEvent('sy_garage:Notification', source, 'El vehículo con placa '..plate ..', ahora es de tu propiedad')

            if Garage.Debug then
                print('El vehículo con placa ' ..
                    plate .. ' ha sido agregado a las propiedades de ' .. xPlayer.getName() .. '.')
            end
        end
    else
        if Garage.Debug then
            print('El jugador '..xPlayer.getName()..' no tiene permisos suficientes para agregar vehículos a las propiedades.')
        end
    end
end)



if Garage.AutoImpound.AutoImpound then
    CreateThread(function()
        while true do
            local vehicles = MySQL.Sync.fetchAll("SELECT * FROM `owned_vehicles`")
            for i = 1, #vehicles do
                local data = vehicles[i]
                local allVehicles = GetAllVehicles()
                local vehicleFound = false
                local xPlayer = ESX.GetPlayerFromIdentifier(data.owner)
                
                for j = 1, #allVehicles do
                    local vehicle = allVehicles[j]
                    if DoesEntityExist(vehicle) then
                        local plate = GetVehicleNumberPlateText(vehicle)
                        if plate == data.plate then
                            vehicleFound = true
                            local ped = GetPedInVehicleSeat(vehicle, -1)
                            if ped == 0 then
                                if data.stored == 0 then
                                    if Garage.Debug then
                                        print('^0Plate: ' .. data.plate .. ', ^1Fuera sin jugador.')
                                    end
                                end
                            else
                                if Garage.Debug then
                                    print('^0Plate: ' .. data.plate .. ', ^2Fuera con jugador.')
                                end
                            end
                        end
                    end
                end
                if not vehicleFound and data.stored == 0 then
                    MySQL.Async.execute(
                        "UPDATE `owned_vehicles` SET `parking` = @impo `pound` = 1 WHERE  `plate` = @plate",
                        {
                            ['@plate'] = data.plate,
                            ['@impo'] = Garage.AutoImpound.ImpoundIn,
                        }, function(rowsChanged)
                            if rowsChanged > 0 then
                                if Garage.Debug then
                                    print('El vehiculo con la matricula ' ..
                                        data.plate .. ' fue depositado en ' .. Garage.AutoImpound.ImpoundIn)
                                end
                            else
                                if Garage.Debug then
                                    print('error')
                                end
                            end
                        end)
                end
            end
            Wait(Garage.AutoImpound.TimeCheck)
        end
    end)
end
