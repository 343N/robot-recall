data:extend({
    {
        name = "recall-speed-modifier",
        type = "double-setting",
        setting_type = "runtime-global",
        default_value = 1,
        minimum_value = 0.1,
        maximum_value = 100
    },

    {
        name = "recall-chest-size",
        type = "int-setting",
        setting_type = "startup",
        default_value = 40,
        minimum_value = 1,
        maximum_value = 320
    }
})