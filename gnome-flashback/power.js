#!/usr/bin/env gjs

const Gio = imports.gi.Gio;
const Gtk = imports.gi.Gtk;
const Lang = imports.lang;
const UPower = imports.gi.UPowerGlib;

const Gettext = imports.gettext;
Gettext.bindtextdomain("gnome-flashback", "/usr/share/locale/");
Gettext.textdomain("gnome-flashback");
window._ = Gettext.gettext;
window.ngettext = Gettext.ngettext;

const Format = imports.format;
String.prototype.format = Format.format;

const BUS_NAME = 'org.freedesktop.UPower';
const OBJECT_PATH = '/org/freedesktop/UPower/devices/DisplayDevice';

const DisplayDeviceInterface = '<node> \
<interface name="org.freedesktop.UPower.Device"> \
  <property name="Type" type="u" access="read"/> \
  <property name="State" type="u" access="read"/> \
  <property name="Percentage" type="d" access="read"/> \
  <property name="TimeToEmpty" type="x" access="read"/> \
  <property name="TimeToFull" type="x" access="read"/> \
  <property name="IsPresent" type="b" access="read"/> \
  <property name="IconName" type="s" access="read"/> \
</interface> \
</node>';

const PowerManagerProxy = Gio.DBusProxy.makeProxyWrapper(DisplayDeviceInterface);

const PowerStatusicon = new Lang.Class({
    Name: 'PowerStatusicon',

    _init: function() {
        this._statusicon = new Gtk.StatusIcon();
        this._statusicon.icon_name = 'battery';
        this._statusicon.title = _("Power status");
        this._statusicon.tooltip_text = _("Power");
        this._statusicon.connect("popup-menu", Lang.bind(this, this._popup));

        this._proxy = new PowerManagerProxy(Gio.DBus.system, BUS_NAME, OBJECT_PATH,
                                            Lang.bind(this, function(proxy, error) {
                                                if (error) {
                                                    log(error.message);
                                                    return;
                                                }
                                                this._proxy.connect('g-properties-changed',
                                                                    Lang.bind(this, this._sync));
                                                this._sync();
                                            }));
    },

    _popup: function(none, icon, button, time) {
        this._popupmenu = new Gtk.Menu();

        this._status = new Gtk.MenuItem();
        this._status.label = this._statusicon.title + _(": ") + this._statusicon.tooltip_text;
        this._status.connect('activate', Lang.bind(this, function() {
            let launcher = Gio.DesktopAppInfo.new_from_filename('/usr/share/applications/gnome-power-statistics.desktop');
            if (launcher)
                launcher.launch([], null);
        }));
        this._popupmenu.append(this._status);

        this._open_settings = new Gtk.MenuItem();
        this._open_settings.label = _("Power Settings");
        this._open_settings.connect('activate', Lang.bind(this, function() {
            let launcher = Gio.DesktopAppInfo.new_from_filename('/usr/share/applications/gnome-power-panel.desktop');
            if (launcher)
                launcher.launch([], null);
        }));
        this._popupmenu.append(this._open_settings);

        this._popupmenu.show_all()
        this._popupmenu.popup(null, null, null, icon.position_menu, button, time);
    },

    _getStatus: function() {
        let seconds = 0;

        if (this._proxy.State == UPower.DeviceState.FULLY_CHARGED)
            return _("Fully Charged");
        else if (this._proxy.State == UPower.DeviceState.CHARGING)
            seconds = this._proxy.TimeToFull;
        else if (this._proxy.State == UPower.DeviceState.DISCHARGING)
            seconds = this._proxy.TimeToEmpty;
        // state is one of PENDING_CHARGING, PENDING_DISCHARGING
        else
            return _("Estimating…");

        let time = Math.round(seconds / 60);
        if (time == 0) {
            // 0 is reported when UPower does not have enough data
            // to estimate battery life
            return _("Estimating…");
        }

        let minutes = time % 60;
        let hours = Math.floor(time / 60);

        if (this._proxy.State == UPower.DeviceState.DISCHARGING) {
            // Translators: this is <hours>:<minutes> Remaining (<percentage>)
            return _("%d\u2236%02d Remaining (%d%%)").format(hours, minutes, this._proxy.Percentage);
        }

        if (this._proxy.State == UPower.DeviceState.CHARGING) {
            // Translators: this is <hours>:<minutes> Until Full (<percentage>)
            return _("%d\u2236%02d Until Full (%d%%)").format(hours, minutes, this._proxy.Percentage);
        }

        return null;
    },

    _sync: function() {
        // Do we have batteries or a UPS?
        this._statusicon.visible = this._proxy.IsPresent;

        // The status icon (without -symbolic suffix)
        let icon = this._proxy.IconName;
        this._statusicon.icon_name = icon.substring(0, icon.length - 9);

        // The status tooltip
        this._statusicon.tooltip_text = this._getStatus();

        // The status title
        if (this._proxy.Type == UPower.DeviceKind.UPS)
            this._statusicon.title = _("UPS");
        else
            this._statusicon.title = _("Battery");
    },
});

Gtk.init (null, null);
var pw = new PowerStatusicon ();
Gtk.main ();
