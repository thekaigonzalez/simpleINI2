/*Copyright 2019-2023 Kai D. Gonzalez*/

import std.stdio : writefln;
import std.file : readText;
import std.string : strip, indexOf, isNumeric, format;
import std.ascii : isAlpha, isDigit;

import core.vararg;

const uint INI_STATE_NAME = 1;
const uint INI_STATE_VALUE = 2;
const uint INI_STATE_STRING = 3;
const uint INI_STATE_SECTION = 4;
const uint INI_STATE_COMMENT = 5;

const char INI_TOKEN_SEPARATOR = '=';
const char INI_TOKEN_COMMENT = ';';
const char INI_NEW_LINE = '\n';

alias ini_state_t = uint;

/* a name */
struct IName
{
    string ptr;
}

/* simply stores a string that can be added to */
struct ITemp
{
    string ptr;
}

/* a parser */
struct IParser
{
    ini_state_t state;
    ITemp buffer;
}

/* a value's type */
enum ini_value_t
{
    INI_VALUE_BOOL = 1,
    INI_VALUE_NUMBER = 2,
    INI_VALUE_STRING = 3,
}

/* an ini key-value pair */
struct IKeyValue
{
    string key;
    string value;
}

/* an ini section */
struct ISection
{
    IKeyValue key_value[];
    string name;
}

/* an ini error */
enum ini_error_t
{
    INI_ERROR_OK,
    INI_ERROR_MISSING_NAME,
    INI_ERROR_MISSING_VALUE,
    INI_ERROR_MISSING_SECTION,
    INI_ERROR_MISSING_KEY,
    INI_BAD_TOKEN,
    INI_WRONG_SIDE,
    INI_DANGLING_EQUAL
}

IName ini_create_name(string name);

ITemp ini_create_temp()
{
    ITemp t;

    t.ptr = "";

    return t;
}

IName ini_create_name(string name)
{
    IName n;
    n.ptr = "";
    n.ptr ~= name;
    return n;
}

bool is_symbol(char c)
{
    return (c == '+' || c == '-' || c == '*' || c == '/');
}

void ini_append_temp(ITemp* temp, char n)
{
    temp.ptr ~= n;
}

string ini_get_temp(ITemp temp)
{
    return temp.ptr;
}

string ini_get_name(IName temp)
{
    return temp.ptr;
}

ulong ini_get_size(ITemp temp)
{
    return temp.ptr.length;
}

void ini_strip_temp(ITemp* temp)
{
    temp.ptr = strip(temp.ptr);
}

bool ini_is_empty(ITemp temp)
{
    return strip(temp.ptr).length == 0;
}

ISection ini_create_section()
{
    ISection s;

    s.key_value = [];
    s.name = "";

    return s;
}

void ini_change_section_name(ISection* section, string name)
{
    section.name = name;
}

void ini_append_key_value(IKeyValue* key_value, string key, string value)
{
    key_value.key = key;
    key_value.value = value;
}

void ini_append_section(ISection* section, IKeyValue* key_value)
{
    section.key_value ~= *key_value;
}

bool isspace(char c)
{
    return (c == ' ' || c == '\t' || c == '\r' || c == '\n');
}

ISection ini_parse_section(string stat, IParser* parser)
{
    int LINE_NO = 1;
    int TOKEN_NO = 1;

    ISection new_section = ini_create_section();

    ini_change_section_name(&new_section, "DEFAULT");
    parser.state = INI_STATE_NAME;

    string _name = "";
    string _value = "";

    if (stat.length == 0)
    {
        ini_error(ini_error_t.INI_ERROR_MISSING_NAME, LINE_NO, TOKEN_NO, 'q');
        return new_section;
    }

    for (uint i = 0; i < stat.length; i++)
    {
        TOKEN_NO++;

        char token = stat[i];

        // if (token == INI_NEW_LINE) {
        //     LINE_NO++;
        //     TOKEN_NO = 1;
        //     // continue;
        // }

        if (token == INI_TOKEN_SEPARATOR && parser.state != INI_STATE_COMMENT) // =
        {
            if (ini_is_empty(parser.buffer))
            {
                ini_error(ini_error_t.INI_DANGLING_EQUAL, LINE_NO, TOKEN_NO, token);
            }
            switch (parser.state)
            {
            case INI_STATE_NAME:
                _name = ini_get_temp(parser.buffer);
                ini_clear_temp(&parser.buffer);
                parser.state = INI_STATE_VALUE; // start collecting the right side of the separator
                break;
            case INI_STATE_VALUE:
                ini_error(ini_error_t.INI_WRONG_SIDE, LINE_NO, TOKEN_NO, token);
                throw new Exception("ini_wrong_side");
            default:
                break;
            }
        }
        else if (token == INI_TOKEN_COMMENT) // #
        {
            parser.state = INI_STATE_COMMENT;
        }
        else if (token == INI_NEW_LINE || i == stat.length - 1 && parser.buffer.ptr.length > 0) // \n or the end of the statements
        {
            if (parser.state == INI_STATE_COMMENT || ini_is_empty(parser.buffer) && _name.length <= 0)
            {
                parser.state = INI_STATE_NAME;
                ini_clear_temp(&parser.buffer);

                TOKEN_NO = 1;
                LINE_NO++;
            }
            else
            {
                if (stat.length > i)
                    ini_append_temp(&parser.buffer, token);

                ini_strip_temp(&parser.buffer);

                _value = ini_get_temp(parser.buffer);

                ini_clear_temp(&parser.buffer);

                if (_name.length == 0)
                {
                    // ini_error(ini_error_t.INI_ERROR_MISSING_NAME, LINE_NO, TOKEN_NO, token);
                    // break;
                }

                IKeyValue kv;

                ini_append_key_value(&kv, _name, _value);

                ini_append_section(&new_section, &kv);

                parser.state = INI_STATE_NAME;
                _name = "";
                _value = "";

                TOKEN_NO = 1;
                LINE_NO++;
            }
        }

        else
        {
            if (!isAlpha(token) && !isspace(token) &&
                !isDigit(token) && !is_symbol(token) && (parser.state == INI_STATE_NAME
                    || parser.state == INI_STATE_VALUE) && parser.state != INI_STATE_COMMENT)
            {
                ini_error(ini_error_t.INI_BAD_TOKEN, LINE_NO, TOKEN_NO, token);
                break;
            }

            ini_append_temp(&parser.buffer, token);
        }

    }

    return new_section;
}

void ini_clear_temp(ITemp* temp)
{
    temp.ptr = "";
}

string ini_get_value_by_key(ISection section, string key)
{
    for (uint i = 0; i < section.key_value.length; i++)
    {
        if (section.key_value[i].key == key)
        {
            return section.key_value[i].value;
        }
    }
    return "";
}

string ini_get_key_by_value(ISection section, string value)
{
    for (uint i = 0; i < section.key_value.length; i++)
    {
        if (section.key_value[i].value == value)
        {
            return section.key_value[i].key;
        }
    }
    return "";
}

void ini_error(ini_error_t error, int line = -1, int token = -1, char optional_token = '\0')
{
    switch (error)
    {
    case ini_error_t.INI_BAD_TOKEN:
        if (optional_token == '\0')
        {
            writefln("%s(%d:%d): bad token", error, line, token);
        }
        else
        {
            writefln("%s(%d:%d): bad token: '%c'", error, line, token, optional_token);
        }
        break;
    case ini_error_t.INI_WRONG_SIDE:
        writefln("%s(%d:%d): double equality is not supported", error, line, token);
        break;
    case ini_error_t.INI_DANGLING_EQUAL:
        writefln("%s(%d:%d): dangling equal (missing name)", error, line, token);
        break;

    case ini_error_t.INI_ERROR_MISSING_NAME:
        writefln("%s(%d:%d): missing name (backup for ini_dangling_equal)", error, line, token);
        break;

    default:
        break;
    }
    throw new Exception(format("%s", error));
}

int main()
{
    ISection s = ini_create_section();

    IKeyValue v;
    ini_append_key_value(&v, "key1", "value1");

    ini_change_section_name(&s, "section1");
    ini_append_section(&s, &v);

    IParser parser;
    ISection root;

    try
    {
        root = ini_parse_section(strip(readText("test.ini")), &parser);
    }
    catch (Exception e)
    {
        writefln("exception: %s", e.msg);
    }
    if (root == cast(ISection) null)
    {
        return 1;
    }

    writefln("section: %s", root.name);

    for (uint i = 0; i < root.key_value.length; i++)
    {
        writefln("key: %s, value: %s", root.key_value[i].key, root.key_value[i].value);
    }
    return 0;
}
