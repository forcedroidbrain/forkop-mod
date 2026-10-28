#!/usr/bin/env ucode

let uci_core = require("core.uci");

const CONFIG_NAME = getenv("FORKOP_CONFIG_NAME") || "forkop";
const OPTION_NAME = "subscription_excluded";

function as_string(value) {
    return value == null ? "" : "" + value;
}

function trim_string(value) {
    return replace(as_string(value), /^[ \t\r\n]+|[ \t\r\n]+$/g, "");
}

function object_or_empty(value) {
    return type(value) == "object" && value != null ? value : {};
}

function section_name(section) {
    if (type(section) == "object")
        return trim_string(section[".name"]);
    return trim_string(section);
}

function valid_section_name(name) {
    return match(as_string(name), /^[A-Za-z0-9_]+$/) != null;
}

function parse_entries(raw) {
    let parsed = raw;
    if (type(raw) == "string") {
        if (trim_string(raw) == "")
            return [];
        try {
            parsed = json(raw);
        }
        catch (e) {
            return [];
        }
    }
    if (type(parsed) != "array")
        return [];

    let entries = [];
    let seen = {};
    for (let item in parsed) {
        let key = "";
        let name = "";
        if (type(item) == "object") {
            key = trim_string(item.key);
            name = trim_string(item.name);
            if (key == "" && name != "")
                key = "sub:" + name;
        }
        else {
            name = trim_string(item);
            if (name != "")
                key = "sub:" + name;
        }
        if (key == "" || seen[key])
            continue;
        if (name == "" && substr(key, 0, 4) == "sub:")
            name = substr(key, 4);
        if (name == "")
            name = key;
        seen[key] = true;
        push(entries, { key, name });
    }
    return entries;
}

function entries_json(entries) {
    entries = parse_entries(entries);
    if (length(entries) == 0)
        return "";
    return sprintf("%J", entries);
}

function write_option(name, entries) {
    name = trim_string(name);
    if (!valid_section_name(name))
        return false;
    let path = CONFIG_NAME + "." + name + "." + OPTION_NAME;
    let text = entries_json(entries);
    if (text == "") {
        uci_core.delete(path);
        return true;
    }
    return uci_core.set(path, text);
}

function list_active() {
    let sections = {};
    for (let section in uci_core.section_objects(CONFIG_NAME, "section")) {
        section = object_or_empty(section);
        let name = section_name(section);
        if (!valid_section_name(name))
            continue;
        let entries = parse_entries(section[OPTION_NAME]);
        if (length(entries) > 0)
            sections[name] = entries;
    }
    return { slot: "", sections };
}

function set_section(name, raw) {
    if (!write_option(name, raw))
        return false;
    return uci_core.commit(CONFIG_NAME);
}

let mode = "";
if (sourcepath(1) == null || sourcepath(1) == "")
    mode = ARGV[0] || "";

if (mode == "get")
    print(sprintf("%J", list_active()), "\n");
else if (mode == "set") {
    if (!set_section(ARGV[1], ARGV[2]))
        exit(1);
    print("{\"ok\":true}\n");
}
else if (mode == "")
    return {
        list_active,
        set_section
    };
