#include < amxmodx >
#include < amxmisc >
#include < fakemeta >
#include < json >

#define ZONE_DRAW_SPRITE "sprites/lgtning.spr"
#define ZONE_DEFAULT_NAME "Default Zone"
#define ZONE_DEFAULT_SIZE_MIN Float:{ -60.0, -60.0, 0.0 }
#define ZONE_DEFAULT_SIZE_MAX Float:{ 60.0, 60.0, 120.0 }
#define ZONE_DEFAULT_RULE_TYPE Rule_LowerThan
#define ZONE_DEFAULT_RULE_ARG 0

#define ZONE_DEFAULT_ID 600
#define ZONE_TASK_EDIT 500

enum MenuName
{
    Menu_Main,
    Menu_SelectZones,
    Menu_ManageMaps,
    Menu_ZoneProperties,
    Menu_ZoneName,
    Menu_ZoneRule,
    Menu_ZoneArgumentNumber,
    Menu_ZoneSize,
    Menu_ZoneMove,
    Menu_Object,
    Menu_ObjectAdd,
    Menu_ObjectProperties,
    Menu_ObjectRotate
}

public Array:Objects;
public ObjectsCount;

public JSON:JSON_Settings;
public BeamTexture;

public Editor;
public EditorSelectedZone;
public EditorSelectedObject;

public bool:Zone_ForwardMove;
public bool:Object_ForwardMove;
public bool:Object_ForwardMoveLockX;
public bool:Object_ForwardMoveLockY;
public bool:Object_ForwardMoveLockZ;

public bool:Debug;

// zone shared libraries
#include "libraries/core.sma"

public Zone[ ZoneStruct ];
public Object[ ObjectStruct ];

public plugin_precache()
{
    register_dictionary( ZONE_DICTIONARY );

    Debug = bool:( plugin_flags() & AMX_FLAG_DEBUG );
    BeamTexture = precache_model( ZONE_DRAW_SPRITE );

    LoadZones( JSON_Settings );
    LoadObjects();
    CreateZones();

    EditorSelectedZone = -1;
    EditorSelectedObject = -1;
}

public plugin_init()
{
    register_plugin( "Zones : Editor", "1.0.0", "AdamRichard21st" );

    register_concmd( "zone_menu", "Zone_CommandMenu", ADMIN_RCON, "Opens the zone editor menu" );
    register_concmd( "ZONE_NAME", "ZoneName", _, "Sets the zone name" );
    register_concmd( "ZONE_NUMBER", "ZoneNumber", _, "Sets the zone argument number" );
}

public plugin_end()
{
    for ( new i = 0, zone[ ZoneStruct ]; i < ZoneCount; i++ )
    {
        ArrayGetArray( Zones, i, zone, ZoneStruct );
        ArrayDestroy( zone[ Zone_Objects ] );
    }

    ArrayDestroy( Zones );
    ArrayDestroy( Objects );

    json_free( JSON_Settings );
}

public client_disconnected( id )
{
    if ( Editor == id )
    {
        ZoneStop();
    }
}

public ZoneName( id )
{
    if ( Editor == id )
    {
        read_args( Zone[ Zone_Name ], charsmax( Zone[ Zone_Name ] ) );
        remove_quotes( Zone[ Zone_Name ] );

        Zone_MenuStruct( id, Menu_ZoneProperties );
    }

    return PLUGIN_HANDLED;
}

public ZoneNumber( id )
{
    if ( Editor == id )
    {
        new data[ 5 ];

        read_args( data, charsmax( data ) );
        remove_quotes( data );

        Zone[ Zone_RuleArgument ] = clamp( str_to_num( data ), 0, MAX_PLAYERS );

        Zone_MenuStruct( id, Menu_ZoneProperties );
    }

    return PLUGIN_HANDLED;
}

public Zone_CommandMenu( id, level, cid )
{
    if ( cmd_access( id, level, cid, 0 ) )
    {
        Zone_Menu( id );
    }
}

public ZoneForwardEdit( task )
{
    if ( EditorSelectedZone == -1 )
    {
        return;
    }

    if ( Zone_ForwardMove || Object_ForwardMove )
    {
        new Float:forigin[ 3 ];
        new origin[ 3 ];

        get_user_origin( Editor, origin, Origin_AimEndEyes );
        IVecFVec( origin, forigin );

        if ( Zone_ForwardMove )
        {
            //Zone[ Zone_Origin ] = forigin;

            Zone[ Zone_Origin ][ 0 ] = forigin[ 0 ];
            Zone[ Zone_Origin ][ 1 ] = forigin[ 1 ];
            Zone[ Zone_Origin ][ 2 ] = forigin[ 2 ];
        }

        if ( Object_ForwardMove )
        {
            if ( !Object_ForwardMoveLockX )
            {
                Object[ Object_Origin ][ 0 ] = forigin[ 0 ];
            }

            if ( !Object_ForwardMoveLockY )
            {
                Object[ Object_Origin ][ 1 ] = forigin[ 1 ];
            }

            if ( !Object_ForwardMoveLockZ )
            {
                Object[ Object_Origin ][ 2 ] = forigin[ 2 ];
            }

            if ( Object[ Object_Entity ] )
            {
                engfunc( EngFunc_SetOrigin, Object[ Object_Entity ], Object[ Object_Origin ] );
            }
        }
    }

    ZoneDraw();
}

public Zone_MenuHandler( id, menu, item )
{
    new info[ 6 ];

    if ( item == MENU_EXIT )
    {
        menu_destroy( menu );
        return;
    }

    menu_item_getinfo( menu, item, .info = info, .infolen = charsmax( info ) );
    menu_destroy( menu );

    switch ( info[ 0 ] )
    {
        case 'a': // Add zone
        {
            Zone_MenuStruct( id, Menu_ZoneMove );
            ZoneInit();

            Zone_ForwardMove = true;
        }
        case 'b': // Edit zones
        {
            switch ( info[ 1 ] )
            {
                case 'a': // Edit zone :: name
                {
                    Zone_MenuStruct( id, Menu_ZoneName );

                    client_cmd( id, "MESSAGEMODE ZONE_NAME" );
                }
                case 'b': // Edit zone :: rule
                {
                    switch ( info[ 2 ] )
                    {
                        case 'a':
                        {
                            Zone_MenuStruct( id, Menu_ZoneRule );
                        }
                        default:
                        {
                            Zone[ Zone_Rule ] = Rule:str_to_num( info[ 2 ] );

                            Zone_MenuStruct( id, Menu_ZoneProperties );
                        }
                    }
                }
                case 'c': // Edit zone :: rule argument
                {
                    Zone_MenuStruct( id, Menu_ZoneArgumentNumber );

                    client_cmd( id, "MESSAGEMODE ZONE_NUMBER" );
                }
                case 'd': // Edit zone :: size
                {
                    new factor = info[ 2 ] == 'a' ? 1 : -1;

                    switch ( info[ 3 ] )
                    {
                        case 'w': Zone[ Zone_SizeMin ][ 0 ] -= 10 * factor, Zone[ Zone_SizeMax ][ 0 ] += 10 * factor;
                        case 'd': Zone[ Zone_SizeMin ][ 1 ] -= 10 * factor, Zone[ Zone_SizeMax ][ 1 ] += 10 * factor;
                        case 'h': Zone[ Zone_SizeMax ][ 2 ] += 10 * factor;
                    }

                    Zone_MenuStruct( id, Menu_ZoneSize );
                }
                case 'e': // Edit zone :: move
                {
                    Zone_MenuStruct( id, Menu_ZoneMove );
                    Zone_ForwardMove = true;
                }
                case 'f': // Edit zone :: objects
                {
                    switch ( info[ 2 ] )
                    {
                        case 'a': // Edit zone :: objects :: add
                        {
                            Zone_MenuStruct( id, Menu_ObjectAdd );
                        }
                        case 'b': // Edit zone :: objects :: select
                        {
                            if ( EditorSelectedObject != -1 )
                            {
                                ArraySetArray( Zone[ Zone_Objects ], EditorSelectedObject, Object, ObjectStruct );
                                Object_RenderEffects( false );
                            }

                            EditorSelectedObject = str_to_num( info[ 3 ] );
                            ArrayGetArray( Zone[ Zone_Objects ], EditorSelectedObject, Object, ObjectStruct );

                            Zone_MenuStruct( id, Menu_ObjectProperties );
                            Object_RenderEffects( true );

                            Object_ForwardMove = false;
                            Object_ForwardMoveLockX = true;
                            Object_ForwardMoveLockY = true;
                            Object_ForwardMoveLockZ = true;
                        }
                        case 'c': // Edit zone :: objects :: add this
                        {
                            new objectId = str_to_num( info[ 3 ] );
                            ArrayGetArray( Objects, objectId, Object, ObjectStruct );

                            EditorSelectedObject = ArrayPushArray( Zone[ Zone_Objects ], Object, ObjectStruct );

                            Object_ForwardMove = true;
                            Object_ForwardMoveLockX = false;
                            Object_ForwardMoveLockY = false;
                            Object_ForwardMoveLockZ = false;
                            
                            Zone_MenuStruct( id, Menu_ObjectProperties );

                            Object_Init( Object );
                            Object_RenderEffects( true );
                        }
                        case 'd': // Edit zone :: objects :: properties
                        {
                            if ( !Object_ForwardMove )
                            {
                                Object_ForwardMoveLockX = true;
                                Object_ForwardMoveLockY = true;
                                Object_ForwardMoveLockZ = true;
                            }

                            Zone_MenuStruct( id, Menu_ObjectProperties );
                        }
                        case 'e': // Edit zone :: objects :: move
                        {
                            switch ( info[ 3 ] )
                            {
                                case 'a', 'b', 'c':
                                {
                                    switch ( info[ 3 ] )
                                    {
                                        case 'a': // Edit zone :: objects :: x axis
                                        {
                                            Object_ForwardMoveLockX = !Object_ForwardMoveLockX;
                                        }
                                        case 'b': // Edit zone :: objects :: y axis
                                        {
                                            Object_ForwardMoveLockY = !Object_ForwardMoveLockY;
                                        }
                                        case 'c': // Edit zone :: objects :: z axis
                                        {
                                            Object_ForwardMoveLockZ = !Object_ForwardMoveLockZ;
                                        }
                                    }
                                }                                        
                                default: Object_ForwardMove = !Object_ForwardMove;
                            }

                            Zone_MenuStruct( id, Menu_ObjectProperties );
                        }
                        case 'f': // Edit zone :: objects :: rotate
                        {
                            switch ( info[ 4 ] )
                            {
                                case '0', '1', '2':
                                {
                                    new factor = info[ 3 ] == 'a' ? 1 : -1;
                                    new axis = str_to_num( info[ 4 ] );

                                    Object_Rotate( 45.0 * factor, axis );
                                }
                            }

                            Zone_MenuStruct( id, Menu_ObjectRotate );
                        }
                        case 'g': // Edit zone :: objects :: delete
                        {
                            Object_Delete();

                            EditorSelectedObject = -1;
                            Object_ForwardMove = false;

                            Zone_MenuStruct( id, Menu_Object );
                        }
                        default:
                        {
                            if ( EditorSelectedObject != -1 )
                            {
                                ArraySetArray( Zone[ Zone_Objects ], EditorSelectedObject, Object, ObjectStruct );
                                Object_RenderEffects( false );
                            }

                            EditorSelectedObject = -1;
                            Object_ForwardMove = false;

                            Zone_MenuStruct( id, Menu_Object );
                        }
                    }
                }
                case 'g': // Edit zone :: delete
                {
                    ZoneDelete();
                    Zone_MenuStruct( id, Menu_SelectZones );
                }
                default: // Edit zone
                {
                    switch ( info[ 1 ] )
                    {
                        case 'y': // List zones
                        {
                            Zone_MenuStruct( id, Menu_SelectZones );
                            return;
                        }
                        case 'z': // Edit this
                        {
                            if ( EditorSelectedZone != -1 )
                            {
                                ArraySetArray( Zones, EditorSelectedZone, Zone, ZoneStruct );
                            }

                            EditorSelectedZone = str_to_num( info[ 2 ] );
                            ArrayGetArray( Zones, EditorSelectedZone, Zone, ZoneStruct );
                        }
                    }

                    Zone_MenuStruct( id, Menu_ZoneProperties );

                    Zone_ForwardMove = false;
                    Object_ForwardMove = false;
                }
            }            
        }
        case 'c': // Manage maps
        {
            if ( info[ 1 ] == 'a' )
            {
                new mapId = str_to_num( info[ 2 ] );
                ZoneDeleteMap( mapId );
            }

            Zone_MenuStruct( id, Menu_ManageMaps );
        }
        case 'd': // Save changes
        {
            if ( SaveZones( JSON_Settings ) )
            {
                new name[ 32 ];
                get_user_name( id, name, charsmax( name ) );
                show_activity( id, name, "%L", LANG_PLAYER, "ZONE_UPDATED" );
            }
            else
            {
                client_print_color( id, print_team_red, "^4[Zone File]^3 %L", id, "ZONE_FILE_ERR2" );
            }

            ZoneStop();
        }
        case 'e': // Main Menu
        {
            if ( EditorSelectedZone != -1 )
            {
                ArraySetArray( Zones, EditorSelectedZone, Zone, ZoneStruct );
            }

            EditorSelectedZone = -1;
            Zone_MenuStruct( id, Menu_Main );
        }
    }
}

Zone_MenuStruct( id, MenuName:menuname )
{
    #define MENU_PACCESS (1 << 26)

    new menu;

    switch ( menuname )
    {
        case Menu_Main:
        {
            // main menu
            menu = menu_create( ML( "[Zone Menu] %L", id, "ZONE_MENU_MAIN" ), "Zone_MenuHandler" );

            // add zone
            menu_additem( menu, ML( "%L", id, "ZONE_MENU_ADD" ), "a" );

            // edit zones
            menu_additem( menu, ML( "%L", id, "ZONE_MENU_EDIT" ), "by", ZoneCount ? 0 : MENU_PACCESS );

            menu_addblank2( menu );

            // manage maps
            menu_additem( menu, ML( "%L", id, "ZONE_MENU_MAPS" ), "c" );

            // save changes
            menu_additem( menu, ML( "%L", id, "ZONE_MENU_SAVE" ), "d" );
        }

        case Menu_SelectZones:
        {
            // Select zone
            menu = menu_create( ML( "[Zone Menu] %L", id, "ZONE_MENU_SELECT" ), "Zone_MenuHandler" );

            for ( new i = 0, info[6], zone[ ZoneStruct ]; i < ZoneCount; i++ )
            {
                ArrayGetArray( Zones, i, zone, ZoneStruct );

                formatex( info, charsmax( info ), "bz%d", i );
                menu_additem( menu, zone[ Zone_Name ], info );
            }

            // back to main menu
            menu_additem( menu, ML( "%L", id, "ZONE_MENU_BACK_MAIN" ), "e" );
        }

        case Menu_ManageMaps:
        {
            // delete map settings
            menu = menu_create( ML( "[Zone Editor] %L", id, "ZONE_MENU_MAP" ), "Zone_MenuHandler" );

            new maps = json_object_get_count( JSON_Settings );

            if ( !maps )
            {
                // no maps defined on file!
                menu_addtext2( menu, ML( "%L", id, "ZONE_MENU_MAP0" ) );
                menu_addblank2( menu );
            }

            for ( new i = 0, map[ 42 ], info[ 6 ]; i < maps; i++ )
            {
                json_object_get_name( JSON_Settings, i, map, charsmax( map ) );

                formatex( info, charsmax( info ), "ca%d", i );
                menu_additem( menu, map, info );
            }

            // back to main menu
            menu_additem( menu, ML( "%L", id, "ZONE_MENU_BACK_MAIN" ), "e" );
        }

        case Menu_ZoneProperties:
        {
            // zone properties
            menu = menu_create( ML( "[Zone Editor] %L", id, "ZONE_MENU_PROPS" ), "Zone_MenuHandler" );

            // zone name
            menu_additem( menu, ML( "%L \d(\y%s\d)", id, "ZONE_NAME", Zone[ Zone_Name ] ), "ba" );

            // zone rule
            menu_additem( menu, ML( "%L \d(\y%L\d)", id, "ZONE_RULE", id, RulesInfo[ _:Zone[ Zone_Rule ] ][ RuleInfo_NameMl ] ), "bba" );

            if ( Zone[ Zone_Rule ] != Rule_Always )
            {
                new arg[ 64 ];
                formatex( arg, charsmax( arg ), "%L \d(\y%L\d:\w%d\d)", id, "ZONE_ARG", id, RulesInfo[ _:Zone[ Zone_Rule ] ][ RuleInfo_NameMl ], Zone[ Zone_RuleArgument ] );

                menu_additem( menu, arg, "bc" );
            }

            // zone size
            menu_additem( menu, ML( "%L", id, "ZONE_MENU_SIZE" ), "bd" );

            // move zone
            menu_additem( menu, ML( "%L", id, "ZONE_MENU_MOVE" ), "be" );

            // objects
            menu_additem( menu, ML( "%L", id, "ZONE_MENU_OBJ" ), "bf" );

            // delete zone
            menu_additem( menu, ML( "%L", id, "ZONE_MENU_DELETE" ), "bg" );

            // back to main menu
            menu_additem( menu, ML( "%L", id, "ZONE_MENU_BACK_MAIN" ), "e" );
        }

        case Menu_ZoneName:
        {
            // zone name
            menu = menu_create( ML( "[Zone Editor] %L", id, "ZONE_MENU_NAME"), "Zone_MenuHandler" );

            // keep current name
            menu_additem( menu, ML( "%L \d(\y%s\d)", id, "ZONE_MENU_KEEP_NAME", Zone[ Zone_Name ] ), "b" );

            menu_addblank2( menu );

            // press [esc] to cancel
            menu_addtext2( menu, ML( "%L", id, "ZONE_MENU_PRESS" ) );
        }

        case Menu_ZoneRule:
        {
            // zone rule
            menu = menu_create( ML( "[Zone Editor] %L", id, "ZONE_MENU_RULE" ), "Zone_MenuHandler" );

            // keep current rule
            menu_additem( menu, ML( "%L \d(\y%L\d)", id, "ZONE_MENU_KEEP_RULE", id, RulesInfo[ _:Zone[ Zone_Rule ] ][ RuleInfo_NameMl ] ), "b" );

            for ( new i = 0, info[ 4 ]; i < sizeof( RulesInfo ); i++ )
            {
                if ( i != _:Zone[ Zone_Rule ] )
                {
                    formatex( info, charsmax( info ), "bb%d", i );
                    menu_additem( menu, ML( "%L", id, RulesInfo[ i ][ RuleInfo_NameMl ] ), info );
                }
            }
        }

        case Menu_ZoneArgumentNumber:
        {
            // zone rule argument
            menu = menu_create( ML( "[Zone Editor] %L", id, "ZONE_MENU_RULE_ARG" ), "Zone_MenuHandler" );

            // keep current argument
            menu_additem( menu, ML( "%L \d(\y%L\d:\w%d\d)", id, "ZONE_MENU_KEEP_ARG", id, RulesInfo[ _:Zone[ Zone_Rule ] ][ RuleInfo_NameMl ], Zone[ Zone_RuleArgument ] ), "b" );
            
            menu_addblank2( menu );

            // press [esc] to cancel
            menu_addtext2( menu, ML( "%L", id, "ZONE_MENU_PRESS" ) );
        }

        case Menu_ZoneSize:
        {
            // zone size
            menu = menu_create( ML( "[Zone Editor] %L", id, "ZONE_MENU_SIZE" ), "Zone_MenuHandler" );

            // Add 10 units to width
            menu_additem( menu, ML( "%L", id, "ZONE_MENU_WIDTH_ADD" ), "bdaw" );

            // Add 10 units to depth
            menu_additem( menu, ML( "%L", id, "ZONE_MENU_DEPTH_ADD" ), "bdad" );

            // Add 10 units to height
            menu_additem( menu, ML( "%L", id, "ZONE_MENU_HEIGHT_ADD" ), "bdah" );

            // Remove 10 units from width
            menu_additem( menu, ML( "%L", id, "ZONE_MENU_WIDTH_DEL" ), "bdbw" );

            // Remove 10 units from depth
            menu_additem( menu, ML( "%L", id, "ZONE_MENU_DEPTH_DEL" ), "bdbd" );

            // Remove 10 units from height
            menu_additem( menu, ML( "%L", id, "ZONE_MENU_HEIGHT_DEL" ), "bdbh" );

            // back to properties
            menu_additem( menu, ML( "%L", id, "ZONE_MENU_BACK_PROPS" ), "b" );
        }

        case Menu_ZoneMove:
        {
            // zone location
            menu = menu_create( ML( "[Zone Editor] %L", id, "ZONE_MENU_LOCATION" ), "Zone_MenuHandler" );

            // confirm location
            menu_additem( menu, ML( "%L", id, "ZONE_MENU_CONFIRM" ), "b" );
        }

        case Menu_Object:
        {
            // objects
            menu = menu_create( ML( "[Zone Editor] %L", id, "ZONE_MENU_OBJ" ), "Zone_MenuHandler" );

            new count = ArraySize( Zone[ Zone_Objects ] );

            if ( count )
            {
                for ( new i = 0, object[ ObjectStruct ], info[ 6 ]; i < count; i++ )
                {
                    ArrayGetArray( Zone[ Zone_Objects ], i, object, ObjectStruct );
                    formatex( info, charsmax( info ), "bfb%d", i );

                    menu_additem( menu, object[ Object_Name ], info );
                }
                menu_addblank2( menu );
            }

            if ( ObjectsCount )
            {
                // add objects
                menu_additem( menu, ML( "%L", id, "ZONE_MENU_OBJ_ADD" ), "bfa" );
            }
            else
            {
                // add objects (no objects defined)
                menu_additem( menu, ML( "%L", id, "ZONE_MENU_OBJ_ADD0" ), "bf", MENU_PACCESS );
            }

            // back to properties
            menu_additem( menu, ML( "%L", id, "ZONE_MENU_BACK_PROPS" ), "b" );
        }

        case Menu_ObjectAdd:
        {
            // add object
            menu = menu_create( ML( "[Zone Editor] %L", id, "ZONE_MENU_OBJ_ADD" ), "Zone_MenuHandler" );

            for ( new i = 0, object[ ObjectStruct ], info[ 6 ]; i < ObjectsCount; i++ )
            {
                ArrayGetArray( Objects, i, object, ObjectStruct );
                formatex( info, charsmax( info ), "bfc%d", i );

                menu_additem( menu, object[ Object_Name ], info );
            }
            
            menu_addblank2( menu );

            // back to objects
            menu_additem( menu, ML( "%L", id, "ZONE_MENU_BACK_OBJ" ), "bf" );
        }

        case Menu_ObjectProperties:
        {
            // object properties
            menu = menu_create( ML( "[Zone Editor] %L", id, "ZONE_MENU_OBJ_PROPS" ), "Zone_MenuHandler" );

            if ( Object_ForwardMove )
            {
                // stop moving object
                menu_additem( menu, ML( "%L", id, "ZONE_MOVE_OBJ_MOVE2" ), "bfe" );

                // unlock/lock x axis
                menu_additem( menu, Object_ForwardMoveLockX ? ML( "%L", id, "ZONE_MENU_UX" ) : ML( "%L", id, "ZONE_MENU_X" ), "bfea" );

                // unlock/lock y axis
                menu_additem( menu, Object_ForwardMoveLockY ? ML( "%L", id, "ZONE_MENU_UY" ) : ML( "%L", id, "ZONE_MENU_Y" ), "bfeb" );

                // unlock/lock z axis
                menu_additem( menu, Object_ForwardMoveLockZ ? ML( "%L", id, "ZONE_MENU_UZ" ) : ML( "%L", id, "ZONE_MENU_Z" ), "bfec" );
            }
            else
            {
                // move object
                menu_additem( menu, ML( "%L", id, "ZONE_MENU_OBJ_MOVE" ), "bfe" );
            }

            // rotate object
            menu_additem( menu, ML( "%L", id, "ZONE_MENU_OBJ_ROTATE" ), "bff" );

            // delete object
            menu_additem( menu, ML( "%L", id, "ZONE_MENU_OBJ_DELETE" ), "bfg" );

            // back to objects
            menu_additem( menu, ML( "%L", id, "ZONE_MENU_BACK_OBJ" ), "bf" );
        }

        case Menu_ObjectRotate:
        {
            // object rotation
            menu = menu_create( ML( "[Zone Editor] %L", id, "ZONE_MENU_OBJ_ROTATION" ), "Zone_MenuHandler" );

            // rotate x axis +45
            menu_additem( menu, ML( "%L", id, "ZONE_MENU_RX" ), "bffa0" );
            
            // rotate y axis +45
            menu_additem( menu, ML( "%L", id, "ZONE_MENU_RY" ), "bffa1" );
            
            // rotate z axis +45
            menu_additem( menu, ML( "%L", id, "ZONE_MENU_RZ" ), "bffa2" );
            
            // rotate x axis -45
            menu_additem( menu, ML( "%L", id, "ZONE_MENU_RUX" ), "bffb0" );
            
            // rotate y axis -45
            menu_additem( menu, ML( "%L", id, "ZONE_MENU_RUY" ), "bffb1" );
            
            // rotate z axis -45
            menu_additem( menu, ML( "%L", id, "ZONE_MENU_RUZ" ), "bffb2" );

            // back to properties
            menu_additem( menu, ML( "%L", id, "ZONE_MENU_BACK_PROPS" ), "bfd" );
        }
    }

    menu_display( id, menu );
}

Zone_Menu( id )
{
    if ( Editor && Editor != id )
    {
        new name[ 32 ];
        get_user_name( id, name, charsmax( name ) );

        client_print_color( id, print_team_red, "^4[Zone Editor]^3 %L", id, "ZONE_HAS_EDITOR", name );
        return;
    }

    Editor = id;

    Zone_ForwardStart();
    Zone_MenuStruct( id, Menu_Main );
}

ZoneInit()
{
    Zone[ Zone_Name ] = ZONE_DEFAULT_NAME;
    Zone[ Zone_SizeMin ] = ZONE_DEFAULT_SIZE_MIN;
    Zone[ Zone_SizeMax ] = ZONE_DEFAULT_SIZE_MAX;
    Zone[ Zone_Origin ] = Float:{ 0.0, 0.0, 0.0 };
    Zone[ Zone_Rule ] = ZONE_DEFAULT_RULE_TYPE;
    Zone[ Zone_RuleArgument ] = ZONE_DEFAULT_RULE_ARG;
    Zone[ Zone_Entity ] = 0;
    Zone[ Zone_Objects ] = ArrayCreate( ObjectStruct );

    EditorSelectedZone = ArrayPushArray( Zones, Zone, ZoneStruct );
    ZoneCount++;
}

Zone_ForwardStart()
{
    if ( !task_exists( ZONE_TASK_EDIT ) )
    {
        set_task( 0.1, "ZoneForwardEdit", .id = ZONE_TASK_EDIT, .flags = "b" );
    }
}

ZoneStop()
{
    remove_task( ZONE_TASK_EDIT );
    Editor = 0;
}

ZoneDelete()
{
    if ( EditorSelectedZone != -1 )
    {
        new count = ArraySize( Zone[ Zone_Objects ] );

        for ( new i = 0, object[ ObjectStruct ]; i < count; i++ )
        {
            ArrayGetArray( Zone[ Zone_Objects ], i, object, ObjectStruct );
            engfunc( EngFunc_RemoveEntity, object[ Object_Entity ] );
        }

        ArrayDeleteItem( Zones, EditorSelectedZone );
        ArrayDestroy( Zone[ Zone_Objects ] );
        ZoneCount--;
    }
    
    EditorSelectedZone = -1;
}

ZoneDeleteMap( mapId )
{
    new map[ 42 ];

    json_object_get_name( JSON_Settings, mapId, map, charsmax( map ) );
    json_object_remove( JSON_Settings, map );

    if ( Debug )
    {
        log_amx( "%L", LANG_SERVER, "ZONE_KEY_DELETE", map );
    }
}

ZoneDraw()
{
    #define ZONE_BOX_COLOR_R 255
    #define ZONE_BOX_COLOR_G 255
    #define ZONE_BOX_COLOR_B 0
    #define ZONE_BOX_LIFE 1

    new Float:absmin[ 3 ];
    new Float:absmax[ 3 ];
    new Float:size[ 3 ];

    absmin[ 0 ] = Zone[ Zone_Origin ][ 0 ] + Zone[ Zone_SizeMin ][ 0 ];
    absmin[ 1 ] = Zone[ Zone_Origin ][ 1 ] + Zone[ Zone_SizeMin ][ 1 ];
    absmin[ 2 ] = Zone[ Zone_Origin ][ 2 ] + Zone[ Zone_SizeMin ][ 2 ];

    absmax[ 0 ] = Zone[ Zone_Origin ][ 0 ] + Zone[ Zone_SizeMax ][ 0 ];
    absmax[ 1 ] = Zone[ Zone_Origin ][ 1 ] + Zone[ Zone_SizeMax ][ 1 ];
    absmax[ 2 ] = Zone[ Zone_Origin ][ 2 ] + Zone[ Zone_SizeMax ][ 2 ];

    size[ 0 ] = absmax[ 0 ] - absmin[ 0 ];
    size[ 1 ] = absmax[ 1 ] - absmin[ 1 ];
    size[ 2 ] = absmax[ 2 ] - absmin[ 2 ];

    UTIL_DrawBeam( Editor, absmin[0], absmin[1], absmin[2], absmin[0] + size[0], absmin[1], absmin[2], 1, 10, 0, ZONE_BOX_COLOR_R, ZONE_BOX_COLOR_G, ZONE_BOX_COLOR_B, 255, 0 )
    UTIL_DrawBeam( Editor, absmin[0], absmin[1], absmin[2], absmin[0], absmin[1] + size[1], absmin[2], 1, 10, 0, ZONE_BOX_COLOR_R, ZONE_BOX_COLOR_G, ZONE_BOX_COLOR_B, 255, 0 )
    UTIL_DrawBeam( Editor, absmin[0], absmin[1], absmin[2], absmin[0], absmin[1], absmin[2] + size[2], 1, 10, 0, ZONE_BOX_COLOR_R, ZONE_BOX_COLOR_G, ZONE_BOX_COLOR_B, 255, 0 )
    UTIL_DrawBeam( Editor, absmin[0] + size[0], absmin[1] + size[1], absmin[2] + size[2], absmin[0], absmin[1] + size[1], absmin[2] + size[2], 1, 10, 0, ZONE_BOX_COLOR_R, ZONE_BOX_COLOR_G, ZONE_BOX_COLOR_B, 255, 0 )
    UTIL_DrawBeam( Editor, absmin[0] + size[0], absmin[1] + size[1], absmin[2] + size[2], absmin[0] + size[0], absmin[1], absmin[2] + size[2], 1, 10, 0, ZONE_BOX_COLOR_R, ZONE_BOX_COLOR_G, ZONE_BOX_COLOR_B, 255, 0 )
    UTIL_DrawBeam( Editor, absmin[0] + size[0], absmin[1] + size[1], absmin[2] + size[2], absmin[0] + size[0], absmin[1] + size[1], absmin[2], 1, 10, 0, ZONE_BOX_COLOR_R, ZONE_BOX_COLOR_G, ZONE_BOX_COLOR_B, 255, 0 )
    UTIL_DrawBeam( Editor, absmin[0] + size[0], absmin[1], absmin[2], absmin[0] + size[0], absmin[1] + size[1], absmin[2], 1, 10, 0, ZONE_BOX_COLOR_R, ZONE_BOX_COLOR_G, ZONE_BOX_COLOR_B, 255, 0 )
    UTIL_DrawBeam( Editor, absmin[0] + size[0], absmin[1], absmin[2], absmin[0] + size[0], absmin[1], absmin[2] + size[2], 1, 10, 0, ZONE_BOX_COLOR_R, ZONE_BOX_COLOR_G, ZONE_BOX_COLOR_B, 255, 0 )
    UTIL_DrawBeam( Editor, absmin[0], absmin[1] + size[1], absmin[2], absmin[0] + size[0], absmin[1] + size[1], absmin[2], 1, 10, 0, ZONE_BOX_COLOR_R, ZONE_BOX_COLOR_G, ZONE_BOX_COLOR_B, 255, 0 )
    UTIL_DrawBeam( Editor, absmin[0], absmin[1] + size[1], absmin[2], absmin[0], absmin[1] + size[1], absmin[2] + size[2], 1, 10, 0, ZONE_BOX_COLOR_R, ZONE_BOX_COLOR_G, ZONE_BOX_COLOR_B, 255, 0 )
    UTIL_DrawBeam( Editor, absmin[0], absmin[1], absmin[2] + size[2], absmin[0] + size[0], absmin[1], absmin[2] + size[2], 1, 10, 0, ZONE_BOX_COLOR_R, ZONE_BOX_COLOR_G, ZONE_BOX_COLOR_B, 255, 0 )
    UTIL_DrawBeam( Editor, absmin[0], absmin[1], absmin[2] + size[2], absmin[0], absmin[1] + size[1], absmin[2] + size[2], 1, 10, 0, ZONE_BOX_COLOR_R, ZONE_BOX_COLOR_G, ZONE_BOX_COLOR_B, 255, 0 )
}

UTIL_DrawBeam( id, Float:start0, Float:start1, Float:start2, Float:end0, Float:end1, Float:end2, life, width, noise, red, green, blue, brightness, speed )
{
	message_begin( MSG_ONE_UNRELIABLE, SVC_TEMPENTITY, { 0, 0, 0 }, id );
	write_byte( TE_BEAMPOINTS );
	write_coord( floatround( start0 ) );
	write_coord( floatround( start1 ) );
	write_coord( floatround( start2 ) );
	write_coord( floatround( end0 ) );
	write_coord( floatround( end1 ) );
	write_coord( floatround( end2 ) );
	write_short( BeamTexture );
	write_byte( 1 ); // framestart
	write_byte( 10 ); // framerate
	write_byte( life ); // life in 0.1's
	write_byte( width ); // width
	write_byte( noise ); // noise
	write_byte( red ); // r, g, b
	write_byte( green ); // r, g, b
	write_byte( blue ); // r, g, b
	write_byte( brightness ); // brightness
	write_byte( speed ); // speed
	message_end();
}

Object_Delete()
{
    ArrayDeleteItem( Zone[ Zone_Objects ], EditorSelectedObject );
    engfunc( EngFunc_RemoveEntity, Object[ Object_Entity ] );
}

Object_Rotate( Float:amount, axis )
{
    Object[ Object_Angles ][ axis ] += amount;
    set_pev( Object[ Object_Entity ], pev_angles, Object[ Object_Angles ] );
}

Object_RenderEffects( bool:render )
{
    if ( render )
    {
        set_pev( Object[ Object_Entity ], pev_rendermode, kRenderTransAdd );
        set_pev( Object[ Object_Entity ], pev_renderamt, 240.0 );
    }
    else
    {
        set_pev( Object[ Object_Entity ], pev_rendermode, kRenderNormal );
    }
}

CreateZones()
{
    for ( new i = 0, count, zone[ ZoneStruct ]; i < ZoneCount; i++ )
    {
        ArrayGetArray( Zones, i, zone, ZoneStruct );
        count = ArraySize( zone[ Zone_Objects ] );

        if ( Debug )
        {
            log_amx( "%L", LANG_SERVER, "ZONE_OBJ_LOAD", count, zone[ Zone_Name ] );
        }
        
        for ( new d = 0, object[ ObjectStruct ]; d < count; d++ )
        {
            ArrayGetArray( zone[ Zone_Objects ], d, object, ObjectStruct );
            Object_Init( object );
            ArraySetArray( zone[ Zone_Objects ], d, object, ObjectStruct );

            if ( Debug )
            {
                log_amx( "%L", LANG_SERVER, "ZONE_OBJ_LOAD2", d + 1, count, object[ Object_Name ], object[ Object_BodyGroup ], object[ Object_SkinFamily ] );
            }
        }
        ArraySetArray( Zones, i, zone, ZoneStruct );
    }
}

LoadObjects()
{
    new configsdir[ 64 ];
    new path[ 92 ];

    get_configsdir( configsdir, charsmax( configsdir ) );
    formatex( path, charsmax( path ), "%s/%s", configsdir, OBJECT_FILES );

    Objects = ArrayCreate( ObjectStruct );

    new file = fopen( path, "r" );

    if ( !file )
    {
        log_amx( "%L", LANG_SERVER, "ZONE_FILE_ERR1", path );
        return;
    }

    new object[ ObjectStruct ];
    new data[ 128 ];
    new body[ 4 ];
    new skin[ 4 ];
    new anim[ 4 ];
    new args;

    while ( fgets( file, data, charsmax( data ) ) )
    {
        trim( data );

        switch ( data[ 0 ] )
        {
            case '#', ';', '/', '\', '*', 0: continue;
            default:
            {
                args = parse( data,
                    object[ Object_Name ], charsmax( object[ Object_Name ] ),
                    object[ Object_Model ], charsmax( object[ Object_Model ] ),
                    body, charsmax( body ),
                    skin, charsmax( skin ),
                    anim, charsmax( anim )
                );
            }
        }

        if ( !PrecacheObject( object[ Object_Model ] ) )
        {
            log_amx( "%L", LANG_SERVER, "ZONE_MDL_ERR1", object[ Object_Model ] );
            continue;
        }

        object[ Object_BodyGroup ] = args > 2 ? str_to_num( body ) : 0;
        object[ Object_SkinFamily ] = args > 3 ? str_to_num( skin ) : 0;
        object[ Object_AnimationId ] = args > 4 ? str_to_num( anim ) : 0;

        if ( Debug )
        {
            log_amx( "Loading object from file.^n^t^"name^":^"%s^"^n^t^"mdl^":^"%s^"^n^t^"body^":%d^n^t^"skin^":%d^n^t^"animation_id^":%d",
                object[ Object_Name ],
                object[ Object_Model ],
                object[ Object_BodyGroup ],
                object[ Object_SkinFamily ],
                object[ Object_AnimationId ]
            );
        }
        
        ArrayPushArray( Objects, object, ObjectStruct );
        ObjectsCount++;
    }
}

// multilingual menu support
ML( const format[], any:... )
{
    new text[ 92 ];
    vformat( text, charsmax( text ), format, 2 );

    return text;
}