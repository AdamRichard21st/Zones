// zone shared functions
// needed to compile both plugins:
// - zone_core.sma
// - zone_editor.sma

#include < amxmodx >
#include < amxmisc >
#include < json >

#define ZONE_FILES "zones.json"
#define ZONE_CLASS "zone_entity"
#define ZONE_BASECLASS "info_target"
#define ZONE_DICTIONARY "zones.txt"

#define OBJECT_FILES "zones.ini"
#define OBJECT_CLASS "zone_object"
#define OBJECT_BASECLASS "info_target"

#define SHOW_ENT(%0) (pev(%0, pev_effects) & ~EF_NODRAW)
#define HIDE_ENT(%0) (pev(%0, pev_effects) | EF_NODRAW)

public Array:Zones;
public ZoneCount;

enum Rule
{
    Rule_Always = 0,
    Rule_LowerThan,
    Rule_HigherThan
}

enum _:RuleInfo
{
    RuleInfo_ID[ 12 ],
    RuleInfo_NameMl[ 12 ],
    RuleInfo_MessageMl[ 12 ]
}

public const RulesInfo[][ RuleInfo ] =
{
    { /* Rule_Always */ "always", "ZONE_RULE1", "ZONE_MSG1" },
    { /* Rule_LowerThan */ "lower_than", "ZONE_RULE2", "ZONE_MSG2" },
    { /* Rule_HigherThan */ "higher_than", "ZONE_RULE3", "ZONE_MSG3" }
}

enum _:ObjectStruct
{
    Object_Name[ 32 ],
    Object_Model[ 64 ],
    Float:Object_Angles[ 3 ],
    Float:Object_Origin[ 3 ],
    Object_BodyGroup,
    Object_SkinFamily,
    Object_AnimationId,
    Object_Entity
}

enum _:ZoneStruct
{
    Zone_Name[ 32 ],
    Float:Zone_SizeMin[ 3 ],
    Float:Zone_SizeMax[ 3 ],
    Float:Zone_Origin[ 3 ],
    Rule:Zone_Rule,
    Zone_RuleArgument,
    Zone_Entity,
    Array:Zone_Objects
}

Object_Init( object[ ObjectStruct ], bool:draw = true )
{
    new ent = engfunc( EngFunc_CreateNamedEntity, engfunc( EngFunc_AllocString, OBJECT_BASECLASS ) );

    if ( pev_valid( ent ) )
    {
        set_pev( ent, pev_classname, OBJECT_CLASS );
        set_pev( ent, pev_solid, SOLID_NOT );
        set_pev( ent, pev_takedamage, DAMAGE_NO );
        set_pev( ent, pev_movetype, MOVETYPE_FLY );
        engfunc( EngFunc_SetModel, ent, object[ Object_Model ] );
        engfunc( EngFunc_SetOrigin, ent, object[ Object_Origin ] );
        set_pev( ent, pev_angles, object[ Object_Angles ] );
        set_pev( ent, pev_body, object[ Object_BodyGroup ] );
        set_pev( ent, pev_skin, object[ Object_SkinFamily ] );
        set_pev( ent, pev_framerate, 1.0 );
        set_pev( ent, pev_sequence, object[ Object_AnimationId ] );
        engfunc( EngFunc_AnimationAutomove, ent, 99999.9 );

        object[ Object_Entity ] = ent;

        set_pev( ent, pev_effects, draw ? SHOW_ENT( ent ) : HIDE_ENT( ent ) );
    }
    else
    {
        log_amx( "Error on creating object %s. [entity:%d]", object[ Object_Name ], ent );
    }
}

LoadZones( &JSON:json = Invalid_JSON )
{
    Zones = ArrayCreate( ZoneStruct );

    new configsdir[ 64 ];
    new file[ 92 ];

    get_configsdir( configsdir, charsmax( configsdir ) );
    formatex( file, charsmax( file ), "%s/%s", configsdir, ZONE_FILES );

    new bool:freeJson = json == Invalid_JSON;
    new JSON:json = json_parse( file, .is_file = true );

    if ( json == Invalid_JSON )
    {
        if ( !freeJson )
        {
            json = json_init_object();
        }

        return;
    }

    new map[ 32 ];
    get_mapname( map, charsmax( map ) );

    if ( !json_object_has_value( json, map, JSONArray, .dot_not = true ) )
    {
        return;
    }

    new JSON:zones = json_object_get_value( json, map, .dot_not = true );
    new size = json_array_get_count( zones );
    new rule[ 2 ];

    for ( new i = 0; i < size; i++ )
    {
        new JSON:zone = json_array_get_value( zones, i );
        new data[ ZoneStruct ];

        json_object_get_string( zone, "name", data[ Zone_Name ], charsmax( data[ Zone_Name ] ) );
        json_object_get_real_array( zone, "origin", data[ Zone_Origin ], 3 );
        json_object_get_real_array( zone, "size.min", data[ Zone_SizeMin ], 3, .dot_not = true );
        json_object_get_real_array( zone, "size.max", data[ Zone_SizeMax ], 3, .dot_not = true );
        json_object_get_string( zone, "when.rule", rule, charsmax( rule ), .dot_not = true ); 

        data[ Zone_RuleArgument ] = json_object_get_number( zone, "when.argument", .dot_not = true );

        new JSON:objects = json_object_get_value( zone, "objects" );

        if ( json_is_array( objects ) )
        {
            new objsize = json_array_get_count( objects );

            data[ Zone_Objects ] = ArrayCreate( ObjectStruct );

            for ( new d = 0, obj[ ObjectStruct ]; d < objsize; d++ )
            {
                new JSON:jobj = json_array_get_value( objects, d );

                json_object_get_string( jobj, "name", obj[ Object_Name ], charsmax( obj[ Object_Name ] ) );
                json_object_get_string( jobj, "mdl", obj[ Object_Model ], charsmax( obj[ Object_Model ] ) );
                json_object_get_real_array( jobj, "angles", obj[ Object_Angles ], 3 );
                json_object_get_real_array( jobj, "origin", obj[ Object_Origin ], 3 );

                obj[ Object_BodyGroup ] = json_object_get_number( jobj, "body" );
                obj[ Object_SkinFamily ] = json_object_get_number( jobj, "skin" );
                obj[ Object_AnimationId ] = json_object_get_number( jobj, "animation_id" );

                json_free( jobj );

                if ( !PrecacheObject( obj[ Object_Model ] ) )
                {
                    continue;
                }

                ArrayPushArray( data[ Zone_Objects ], obj, ObjectStruct );
            }
        }
        
        json_free( zone );

        switch ( rule[ 0 ] )
        {
            case /* "always"        */ 'a': data[ Zone_Rule ] = Rule_Always;
            case /* "lower_than"    */ 'l': data[ Zone_Rule ] = Rule_LowerThan;
            case /* "higher_than"   */ 'h': data[ Zone_Rule ] = Rule_HigherThan;
        }
        
        ArrayPushArray( Zones, data, ZoneStruct );
        ZoneCount++;
    }

    if ( freeJson )
    {
        json_free( zones );
    }
}

PrecacheObject( const model[] )
{
    if ( file_exists( model, .use_valve_fs = true ) )
    {
        new modelT[ 64 ];

        new len = copy( modelT, charsmax( modelT ), model );
        copy( modelT[ len - 4 ], charsmax( modelT ) - len, "T.mdl" );

        if ( file_exists( modelT, .use_valve_fs = true ) )
        {
            precache_model( modelT );
        }

        precache_model( model );

        return true;
    }

    return false;
}

stock SaveZones( &JSON:json )
{
    if ( json == Invalid_JSON )
    {
        return false;
    }

    new JSON:jmap = json_init_array();

    for ( new i = 0, data[ ZoneStruct ]; i < ZoneCount; i++ )
    {
        ArrayGetArray( Zones, i, data, ZoneStruct );

        new JSON:jdata = json_init_object();
        new JSON:jobjects = json_init_array();

        new objects = ArraySize( data[ Zone_Objects ] );

        for ( new d = 0, obj[ ObjectStruct ]; d < objects; d++ )
        {
            ArrayGetArray( data[ Zone_Objects ], d, obj, ObjectStruct );

            new JSON:jobj = json_init_object();

            json_object_set_string( jobj, "name", obj[ Object_Name ] );
            json_object_set_string( jobj, "mdl", obj[ Object_Model ] );
            json_object_set_real_array( jobj, "angles", obj[ Object_Angles ], 3 );
            json_object_set_real_array( jobj, "origin", obj[ Object_Origin ], 3 );
            json_object_set_number( jobj, "body", obj[ Object_BodyGroup ] );
            json_object_set_number( jobj, "skin", obj[ Object_SkinFamily ] );
            json_object_set_number( jobj, "animation_id", obj[ Object_AnimationId ] );            

            json_array_append_value( jobjects, jobj );
            json_free( jobj );
        }

        json_object_set_string( jdata, "name", data[ Zone_Name ] );
        json_object_set_string( jdata, "when.rule", RulesInfo[ _:data[ Zone_Rule ] ][ RuleInfo_ID ], .dot_not = true );
        json_object_set_number( jdata, "when.argument", data[ Zone_RuleArgument ], .dot_not = true );
        json_object_set_real_array( jdata, "origin", data[ Zone_Origin ], 3, .dot_not = true );
        json_object_set_real_array( jdata, "size.min", data[ Zone_SizeMin ], 3, .dot_not = true );
        json_object_set_real_array( jdata, "size.max", data[ Zone_SizeMax ], 3, .dot_not = true );
        json_object_set_value( jdata, "objects", jobjects );

        json_array_append_value( jmap, jdata );

        json_free( jobjects );
        json_free( jdata );
    }

    new map[ 43 ];
    get_mapname( map, charsmax( map ) );

    json_object_set_value( json, map, jmap );
    json_free( jmap );

    new configsdir[ 64 ];
    new file[ 92 ];

    get_configsdir( configsdir, charsmax( configsdir ) );
    formatex( file, charsmax( file ), "%s/%s", configsdir, ZONE_FILES );

    return json_serial_to_file( json, file, .pretty = true );
}

stock json_object_set_real_array( JSON:object, const name[], Float:data[], size, bool:dot_not = false )
{
    new JSON:array = json_init_array();

    for ( new i = 0; i < size; i++ )
    {
        json_array_append_real( array, data[ i ] );
    }

    json_object_set_value( object, name, array, dot_not );
    json_free( array );
}

stock json_object_get_real_array( JSON:object, const name[], Float:data[], size, bool:dot_not = false )
{
    new JSON:array = json_object_get_value( object, name, dot_not );
    new len = json_array_get_count( array );

    size = len < size ? len : size;

    for ( new i = 0; i < size; i++ )
    {
        data[ i ] = json_array_get_real( array, i );
    }

    json_free( array );
}