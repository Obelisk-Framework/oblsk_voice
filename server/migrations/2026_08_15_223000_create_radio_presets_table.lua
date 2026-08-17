-- core/modules/oblsk_voice/server/migrations/2026_08_15_223000_create_radio_presets_table.lua
--- Migration: Create radio_presets table, and copy any existing rows over
--- from oblsk_phone's phone_radio_presets (which a companion migration in
--- oblsk_phone drops afterward - see
--- core/plugins/oblsk_phone/server/migrations/2026_08_15_223500_drop_phone_radio_presets_table.lua).
--- Safe on a fresh install: phone_radio_presets won't exist yet, the copy
--- is skipped. Runs before any plugin migration - core/server/bootstrap.lua
--- runs every module's migrations before any plugin's, so this always lands
--- before oblsk_phone's drop.
return {
    up = function()
        Schema.create('radio_presets', function(table)
            table:id()
            table:integer('character_id'):index()
            table:string('frequency', 20)
            table:string('label', 100):nullable()
            table:timestamps()
        end)

        if Schema.hasTable('phone_radio_presets') then
            Database.execute(
                'INSERT INTO radio_presets (character_id, frequency, label, created_at, updated_at) '
                .. 'SELECT character_id, frequency, label, created_at, updated_at FROM phone_radio_presets'
            )
            print('[Migration] Copied existing rows from phone_radio_presets into radio_presets')
        end

        print('[Migration] Created radio_presets table')
    end,

    down = function()
        Schema.drop('radio_presets')
        print('[Migration] Dropped radio_presets table')
    end
}
