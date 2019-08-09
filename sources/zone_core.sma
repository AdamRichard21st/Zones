#include < amxmodx >
#include < engine >
#include < fakemeta >

// just a valid model in order to create a solid entity
#define INTERNAL_MODEL "models/w_weaponbox.mdl"

#define ZoneStatus(%0)          pev(%0, pev_iuser1)
#define ZoneRule(%0)            pev(%0, pev_iuser2)
#define ZoneRuleArg(%0)         pev(%0, pev_iuser3)

#define ZoneSetStatus(%0,%1)    set_pev(%0, pev_iuser1, %1)
#define ZoneSetRule(%0,%1)      set_pev(%0, pev_iuser2, %1)
#define ZoneSetRuleArg(%0,%1)   set_pev(%0, pev_iuser3, %1)

// zone shared libraries
#include "libraries/core.sma"

public OnPlayerTouch;
public OnWeaponTouch;

public plugin_init()
{
    register_plugin( "Zones : Core", "1.0.0", "AdamRichard21st" );

    if ( !ZoneCount )
    {
        return;
    }

    register_event_ex( "HLTV", "On_NewRound", RegisterEvent_Global, "1=0", "2=0" );
    register_dictionary( ZONE_DICTIONARY );
}

public plugin_precache()
{
    precache_model( INTERNAL_MODEL );
    LoadZones();

    for ( new i = 0, zone[ ZoneStruct ]; i < ZoneCount; i++ )
    {
        ArrayGetArray( Zones, i, zone, ZoneStruct );
        CreateZone( zone );
        ArraySetArray( Zones, i, zone, ZoneStruct );
    }
}

public On_NewRound()
{
    new players[ MAX_PLAYERS ];
    new trnum;
    new ctnum;

    get_players_ex( players, trnum, GetPlayers_MatchTeam, "TERRORIST" );
    get_players_ex( players, ctnum, GetPlayers_MatchTeam, "CT" );

    new count = trnum + ctnum;
    new bool:enableTouch;

    for ( new i = 0, zone[ ZoneStruct ]; i < ZoneCount; i++ )
    {
        new bool:shouldEnable = false;

        ArrayGetArray( Zones, i, zone, ZoneStruct );

        switch ( zone[ Zone_Rule ] )
        {
            case Rule_Always: shouldEnable = true;
            case Rule_LowerThan: shouldEnable = count < zone[ Zone_RuleArgument ];
            case Rule_HigherThan: shouldEnable = count > zone[ Zone_RuleArgument ];
        }

        SetZoneStatus( zone, shouldEnable );
        ArraySetArray( Zones, i, zone, ZoneStruct );

        enableTouch = enableTouch || shouldEnable;
    }

    if ( enableTouch && (!OnPlayerTouch || !OnWeaponTouch) )
    {
        OnPlayerTouch = register_touch( ZONE_CLASS, "player", "On_Touch" );
        OnWeaponTouch = register_touch( "weaponbox", ZONE_CLASS, "On_TouchWeapon" );
    }
    else if ( !enableTouch && (OnPlayerTouch || OnWeaponTouch) )
    {
        unregister_touch( OnPlayerTouch );
        unregister_touch( OnWeaponTouch );

        OnPlayerTouch = 0;
        OnWeaponTouch = 0;
    }
}

public On_Touch( ent, id )
{
    if ( !ZoneStatus( ent ) || !is_user_connected( id ) )
    {
        return;
    }

    new rule = ZoneRule( ent );

    switch ( Rule:rule )
    {
        case Rule_Always: client_print( id, print_center, "%L", id, RulesInfo[ rule ][ RuleInfo_MessageMl ] );
        case Rule_LowerThan, Rule_HigherThan: client_print( id, print_center, "%L", id, RulesInfo[ rule ][ RuleInfo_MessageMl ], ZoneRuleArg( ent ) );
    }
}

public On_TouchWeapon( weapon, ent )
{
    if ( !pev_valid( weapon ) || pev( weapon, pev_iuser1 ) || !ZoneStatus( ent ) )
    {
        return;
    }

    new Float:velocity[ 3 ];

    pev( weapon, pev_velocity, velocity );

    // kinda poor way to simulate a collision, but ...
    velocity[ 0 ] = 0.0;
    velocity[ 1 ] = 0.0;

    set_pev( weapon, pev_velocity, velocity );
    set_pev( weapon, pev_iuser1, 1 );
}

SetZoneStatus( zone[ ZoneStruct ], bool:enable )
{
    new bool:shouldDisable = enable && !ZoneStatus( zone[ Zone_Entity ] );
    new bool:shouldEnable = !enable && ZoneStatus( zone[ Zone_Entity ] );

    if ( shouldDisable || shouldEnable )
    {
        set_pev( zone[ Zone_Entity ], pev_solid, enable ? SOLID_BBOX : SOLID_NOT );
        ZoneSetStatus( zone[ Zone_Entity ], enable ? 1 : 0 );

        new count = ArraySize( zone[ Zone_Objects ] );

        for ( new i = 0, object[ ObjectStruct ]; i < count; i++ )
        {
            ArrayGetArray( zone[ Zone_Objects ], i, object, ObjectStruct );
            set_pev( object[ Object_Entity ], pev_effects, enable ? SHOW_ENT(object[ Object_Entity ]) : HIDE_ENT(object[ Object_Entity ]) );
        }
    }
}

CreateZone( zone[ ZoneStruct ] )
{
    new ent = engfunc( EngFunc_CreateNamedEntity, engfunc( EngFunc_AllocString, ZONE_BASECLASS ) );

    if ( pev_valid( ent ) )
    {
        set_pev( ent, pev_classname, ZONE_CLASS );
        set_pev( ent, pev_solid, SOLID_NOT );
        set_pev( ent, pev_takedamage, DAMAGE_NO );
        set_pev( ent, pev_movetype, MOVETYPE_FLY );

        engfunc( EngFunc_SetModel, ent, INTERNAL_MODEL );
        engfunc( EngFunc_SetOrigin, ent, zone[ Zone_Origin ] );
        engfunc( EngFunc_SetSize, ent, zone[ Zone_SizeMin ], zone[ Zone_SizeMax ] );

        set_pev( ent, pev_effects, HIDE_ENT( ent ) );

        ZoneSetStatus( ent, 0 );
        ZoneSetRule( ent, _:zone[ Zone_Rule ]  );
        ZoneSetRuleArg( ent, zone[ Zone_RuleArgument ] );

        zone[ Zone_Entity ] = ent;

        new count = ArraySize( zone[ Zone_Objects ] );

        for ( new i = 0, object[ ObjectStruct ]; i < count; i++ )
        {
            ArrayGetArray( zone[ Zone_Objects ], i, object, ObjectStruct );
            Object_Init( object, .draw = false );
            ArraySetArray( zone[ Zone_Objects ], i, object, ObjectStruct );
        }
    }
    else
    {
        log_amx( "Error on creating zone %s. [entity:%d]", zone[ Zone_Name ], ent );
    }
}