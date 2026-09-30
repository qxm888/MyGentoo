#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""gnome-keyring 命令行小工具：操作 master password / 导出密钥环内容
用法:
  gkrctl.py list                       列出所有集合及其锁定状态/条目
  gkrctl.py dump                       导出所有已解锁集合的条目
  gkrctl.py create  <label> <password> 新建集合并设主密码
  gkrctl.py change  <path|label> <old> <new>   修改主密码
  gkrctl.py unlock  <path|label> <password>    用主密码解锁
"""
import sys
import gi

gi.require_version("GLib", "2.0")
gi.require_version("Gio", "2.0")
from gi.repository import GLib, Gio  # noqa: E402

SVC = "org.freedesktop.secrets"
ROOT = "/org/freedesktop/secrets"


def bus():
    return Gio.bus_get_sync(Gio.BusType.SESSION)


def call(b, path, iface, method, params, sig=None, reply=None):
    if sig is None:
        res = b.call_sync(SVC, path, iface, method, params, None,
                          Gio.DBusCallFlags.NONE, -1, None)
    else:
        res = b.call_sync(SVC, path, iface, method,
                          GLib.Variant(sig, params), GLib.VariantType(reply) if reply else None,
                          Gio.DBusCallFlags.NONE, -1, None)
    return res.unpack()


def prop(b, path, iface, name):
    return call(b, path, "org.freedesktop.DBus.Properties", "Get",
                GLib.Variant("(ss)", (iface, name)))[0]


def open_session(b):
    """返回 (session_path, aes_key or None)"""
    out, sess = call(b, ROOT, "org.freedesktop.Secret.Service", "OpenSession",
                     GLib.Variant("(sv)", ("plain", GLib.Variant("s", ""))))[:2]
    return sess


def collections(b):
    return prop(b, ROOT, "org.freedesktop.Secret.Service", "Collections")


def secret_variant(session, value_bytes, content_type="text/plain"):
    """构造 (oayays) 结构"""
    return (session, b"", value_bytes, content_type)


def resolve(b, path_or_label):
    if path_or_label.startswith("/"):
        return path_or_label
    for c in collections(b):
        label = prop(b, c, "org.freedesktop.Secret.Collection", "Label")
        if label == path_or_label or c.endswith("/" + path_or_label):
            return c
    raise SystemExit("找不到集合: %s" % path_or_label)


def cmd_list(b, args):
    for c in collections(b):
        label = prop(b, c, "org.freedesktop.Secret.Collection", "Label")
        locked = prop(b, c, "org.freedesktop.Secret.Collection", "Locked")
        items = prop(b, c, "org.freedesktop.Secret.Collection", "Items")
        print("%-60s label=%-16s locked=%-5s items=%d" % (c, label, locked, len(items)))
        for it in items:
            ilabel = prop(b, it, "org.freedesktop.Secret.Item", "Label")
            attrs = prop(b, it, "org.freedesktop.Secret.Item", "Attributes")
            print("    - %s  attrs=%s" % (ilabel, dict(attrs)))


def cmd_dump(b, args):
    sess = open_session(b)
    for c in collections(b):
        label = prop(b, c, "org.freedesktop.Secret.Collection", "Label")
        locked = prop(b, c, "org.freedesktop.Secret.Collection", "Locked")
        items = prop(b, c, "org.freedesktop.Secret.Collection", "Items")
        print("=== 集合: %s (%s) locked=%s" % (label, c, locked))
        if locked:
            print("    [已锁定，无法读取]")
            continue
        for it in items:
            ilabel = prop(b, it, "org.freedesktop.Secret.Item", "Label")
            attrs = prop(b, it, "org.freedesktop.Secret.Item", "Attributes")
            try:
                sec = call(b, it, "org.freedesktop.Secret.Item", "GetSecret",
                           GLib.Variant("(o)", (sess,)))[0]
                _, _, value, ctype = sec
                try:
                    text = bytes(value).decode("utf-8")
                except Exception:
                    text = repr(bytes(value))
                print("  [%s] attrs=%s\n      secret(%s)=%s" % (ilabel, dict(attrs), ctype, text))
            except GLib.Error as e:
                print("  [%s] 读取失败: %s" % (ilabel, e.message))


def cmd_create(b, args):
    label, password = args[0], args[1]
    sess = open_session(b)
    attrs = {"org.freedesktop.Secret.Collection.Label": GLib.Variant("s", label)}
    coll = call(b, ROOT, "org.gnome.keyring.InternalUnsupportedGuiltRiddenInterface",
                "CreateWithMasterPassword",
                GLib.Variant("(a{sv}(oayays))", (attrs, secret_variant(sess, password.encode()))))[0]
    print("已创建:", coll)


def cmd_unlock(b, args):
    target, password = resolve(b, args[0]), args[1]
    sess = open_session(b)
    call(b, ROOT, "org.gnome.keyring.InternalUnsupportedGuiltRiddenInterface",
         "UnlockWithMasterPassword",
         GLib.Variant("(o(oayays))", (target, secret_variant(sess, password.encode()))))
    locked = prop(b, target, "org.freedesktop.Secret.Collection", "Locked")
    print("解锁后 locked =", locked)


def cmd_change(b, args):
    target, old, new = resolve(b, args[0]), args[1], args[2]
    sess = open_session(b)
    call(b, ROOT, "org.gnome.keyring.InternalUnsupportedGuiltRiddenInterface",
         "ChangeWithMasterPassword",
         GLib.Variant("(o(oayays)(oayays))",
                      (target, secret_variant(sess, old.encode()), secret_variant(sess, new.encode()))))
    print("主密码已修改:", target)


CMDS = {"list": cmd_list, "dump": cmd_dump, "create": cmd_create,
        "unlock": cmd_unlock, "change": cmd_change}

if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] not in CMDS:
        print(__doc__)
        raise SystemExit(1)
    CMDS[sys.argv[1]](bus(), sys.argv[2:])
