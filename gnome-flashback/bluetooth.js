#!/usr/bin/env gjs

const Gio = imports.gi.Gio;
const Gtk = imports.gi.Gtk;
const GnomeBluetooth = imports.gi.GnomeBluetooth;
const Lang = imports.lang;

const Gettext = imports.gettext;
Gettext.bindtextdomain("gnome-flashback", "/usr/share/locale/");
Gettext.textdomain("gnome-flashback");
window._ = Gettext.gettext;
window.ngettext = Gettext.ngettext;

const Format = imports.format;
String.prototype.format = Format.format;

const BUS_NAME = 'org.gnome.SettingsDaemon.Rfkill';
const OBJECT_PATH = '/org/gnome/SettingsDaemon/Rfkill';

const RfkillManagerInterface = '<node> \
<interface name="org.gnome.SettingsDaemon.Rfkill"> \
<property name="BluetoothAirplaneMode" type="b" access="readwrite" /> \
<property name="BluetoothHasAirplaneMode" type="b" access="read" /> \
</interface> \
</node>';

const RfkillManagerProxy = Gio.DBusProxy.makeProxyWrapper(RfkillManagerInterface);


const BluetoothStatusicon = new Lang.Class({
    Name: 'BluetoothStatusicon',

    _init: function() {
        this._statusicon = new Gtk.StatusIcon();
        this._statusicon.icon_name = 'bluetooth-active';
        this._statusicon.title = _("Bluetooth");
        this._statusicon.tooltip_text = _("Bluetooth");
        this._statusicon.connect("popup-menu", Lang.bind(this, this._popup));

        this._proxy = new RfkillManagerProxy(Gio.DBus.session, BUS_NAME, OBJECT_PATH,
                                             Lang.bind(this, function(proxy, error) {
                                                 if (error) {
                                                     log(error.message);
                                                     return;
                                                 }

                                                 this._sync();
                                             }));
        this._proxy.connect('g-properties-changed', Lang.bind(this, this._sync));

        this._client = new GnomeBluetooth.Client();
        this._model = this._client.get_model();
        this._model.connect('row-changed', Lang.bind(this, this._sync));
        this._model.connect('row-deleted', Lang.bind(this, this._sync));
        this._model.connect('row-inserted', Lang.bind(this, this._sync));
        this._sync();
    },

    _popup: function(none, icon, button, time) {
        this._popupmenu = new Gtk.Menu();

        if (!this._proxy.BluetoothAirplaneMode) {
            this._turn_off = new Gtk.MenuItem();
            this._turn_off.label = _("Turn Off");
            this._turn_off.connect('activate', Lang.bind(this, function() {
                this._proxy.BluetoothAirplaneMode = true;
            }));
            this._popupmenu.append(this._turn_off);

            this._send_files = new Gtk.MenuItem();
            this._send_files.label = _("Send Files");
            this._send_files.connect('activate', Lang.bind(this, function() {
                let launcher = Gio.DesktopAppInfo.new_from_filename('/usr/share/applications/bluetooth-sendto.desktop');
                if (launcher)
                    launcher.launch([], null);
            }));
            this._popupmenu.append(this._send_files);
        } else {
            this._turn_on = new Gtk.MenuItem();
            this._turn_on.label = _("Turn On");
            this._turn_on.connect('activate', Lang.bind(this, function() {
                this._proxy.BluetoothAirplaneMode = false;
            }));
            this._popupmenu.append(this._turn_on);
        }

        this._open_settings = new Gtk.MenuItem();
        this._open_settings.label = _("Bluetooth Settings");
        this._open_settings.connect('activate', Lang.bind(this, function() {
            let launcher = Gio.DesktopAppInfo.new_from_filename('/usr/share/applications/gnome-bluetooth-panel.desktop');
            if (launcher)
                launcher.launch([], null);
        }));
        this._popupmenu.append(this._open_settings);

        this._popupmenu.show_all()
        this._popupmenu.popup(null, null, null, icon.position_menu, button, time);
    },

    _getDefaultAdapter: function() {
        let [ret, iter] = this._model.get_iter_first();
        while (ret) {
            let isDefault = this._model.get_value(iter,
                                                  GnomeBluetooth.Column.DEFAULT);
            if (isDefault)
                return iter;
            ret = this._model.iter_next(iter);
        }
        return null;
    },

    _getNConnectedDevices: function() {
        let adapter = this._getDefaultAdapter();
        if (!adapter)
            return 0;

        let nDevices = 0;
        let [ret, iter] = this._model.iter_children(adapter);
        while (ret) {
            let isConnected = this._model.get_value(iter,
                                                    GnomeBluetooth.Column.CONNECTED);
            if (isConnected)
                nDevices++;
            ret = this._model.iter_next(iter);
        }
        return nDevices;
    },

    _sync: function() {
        let nDevices = this._getNConnectedDevices();
        this._statusicon.visible = this._proxy.BluetoothHasAirplaneMode;

        if (!this._proxy.BluetoothAirplaneMode) {
            this._statusicon.icon_name = 'bluetooth-active';
            this._statusicon.title = _("Bluetooth active");
        } else {
            this._statusicon.icon_name = 'bluetooth-disabled';
            this._statusicon.title = _("Bluetooth disabled");
        }

        if (nDevices > 0)
            this._statusicon.tooltip_text = ngettext("%d Connected Device", "%d Connected Devices", nDevices).format(nDevices);
        else
            this._statusicon.tooltip_text = _("Not Connected");
    },
});

Gtk.init (null, null);
var bt = new BluetoothStatusicon ();
Gtk.main ();
