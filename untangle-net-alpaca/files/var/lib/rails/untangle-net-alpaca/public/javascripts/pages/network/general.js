Ext.ns("Ung");
Ext.ns("Ung.Alpaca");
Ext.ns("Ung.Alpaca.Pages");
Ext.ns("Ung.Alpaca.Pages.Network");

if ( Ung.Alpaca.Glue.hasPageRenderer( "network", "general" )) {
    Ung.Alpaca.Util.stopLoading();
}

Ung.Alpaca.Pages.Network.General = Ext.extend( Ung.Alpaca.PagePanel, {
    initComponent : function()
    {
        Ext.apply( this, {
            defaults : {
                xtype : "fieldset"
            },
            items : [{
                xtype : "label",
                cls: "page-header-text",
                html : this._( "General Settings" )
            },{
                xtype : "fieldset",
                autoHeight : true,
                defaults : {
                    xtype : "checkbox",
                    itemCls : "label-width-2"
                },
                items : [{
                    fieldLabel : this._( "Send ICMP Redirects" ),
                    name : "send_icmp_redirects"
                },{
                    fieldLabel : this._( "Enable SIP Helper" ),
                    name : "enable_sip_helper"
                },{
                    fieldLabel : this._( "Administration overrides Port Forwards" ),
                    name : "uvm.override_redirects"
                },{
                    fieldLabel : this._( "Legacy NAT Mode" ),
                    name : "legacy_nat_mode"
                }]
            }]
        });

        this.confirmMessage = this._( "These settings are critical to proper network operation and you should be sure these are the settings you want. You may be logged out." );
        
        Ung.Alpaca.Pages.Network.General.superclass.initComponent.apply( this, arguments );
    },

    saveMethod : "/network/set_general_settings"    
});

Ung.Alpaca.Pages.Network.General.settingsMethod = "/network/get_general_settings";
Ung.Alpaca.Glue.registerPageRenderer( "network", "general", Ung.Alpaca.Pages.Network.General );


