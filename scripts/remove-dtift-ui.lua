script_name('Remove Arizona Drift Interface');
script_author('chapo');
script_url('https://t.me/chaposcripts');

local models = {
    [19476] = true, -- Интерфейс
    [19478] = true, -- какая то хуетень
    [18728] = true -- Красный дым
};
require('lib.samp.events').onCreateObject = function(id, data)
    if (isCharInAnyCar(PLAYER_PED)) then
        local vehHandle = storeCarCharIsInNoSave(PLAYER_PED);
        local result, vehId = sampGetVehicleIdByCarHandle(vehHandle);
        if (result and data.attachToVehicleId == vehId) then
            if (models[data.modelId]) then
                return false;
            end
        end
    end
end