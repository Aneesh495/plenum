// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Pure Dream Maker JSON Tokenizer & Serializer
// Language: Dream Maker (DM)

#ifndef PLENUM_LIBRARIES_JSON_DM
#define PLENUM_LIBRARIES_JSON_DM

#include "../core/datum.dm"

/datum/json_engine
    var/tag_name = "json_engine"

/datum/json_engine/proc/Serialize(list/data_obj, indent_spaces = 2)
    return StringifyValue(data_obj, 0, indent_spaces)

/datum/json_engine/proc/StringifyValue(val, depth = 0, indent_spaces = 2)
    if(isnull(val))
        return "null"
    if(isnum(val))
        return "[val]"
    if(istext(val))
        return "\"[val]\""
    if(islist(val))
        var/list/L = val
        var/is_assoc = FALSE
        for(var/key in L)
            if(istext(key))
                is_assoc = TRUE
                break

        var/pad = ""
        var/pad_inner = ""
        if(indent_spaces > 0)
            for(var/p = 1 to (depth * indent_spaces)) pad += " "
            for(var/p = 1 to ((depth + 1) * indent_spaces)) pad_inner += " "

        if(is_assoc)
            var/out = "{\n"
            var/count = 0
            for(var/key in L)
                count++
                out += "[pad_inner]\"[key]\": [StringifyValue(L[key], depth + 1, indent_spaces)]"
                if(count < L.len)
                    out += ","
                out += "\n"
            out += "[pad]}"
            return out
        else
            var/out = "[\n"
            for(var/i = 1 to L.len)
                out += "[pad_inner][StringifyValue(L[i], depth + 1, indent_spaces)]"
                if(i < L.len)
                    out += ","
                out += "\n"
            out += "[pad]]"
            return out

    return "\"unknown\""

#endif // PLENUM_LIBRARIES_JSON_DM
