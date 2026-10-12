module model

import math
import strings
import x.json2

// encode_json serializes a JSON value the way Alda's Go client does (Go's
// encoding/json): object keys sorted, HTML-sensitive characters escaped, and
// numbers in their shortest form.
pub fn encode_json(value json2.Any) string {
	mut sb := strings.new_builder(4096)
	write_json(value, '', 0, mut sb)
	return sb.str()
}

// encode_json_pretty is like encode_json, indented with two spaces.
pub fn encode_json_pretty(value json2.Any) string {
	mut sb := strings.new_builder(4096)
	write_json(value, '  ', 0, mut sb)
	return sb.str()
}

fn newline(indent string, depth int, mut sb strings.Builder) {
	if indent != '' {
		sb.write_u8(`\n`)
		sb.write_string(indent.repeat(depth))
	}
}

// format_number formats a float like Go's encoding/json.
pub fn format_number(x f64) string {
	if math.is_nan(x) || math.is_inf(x, 0) {
		return 'null'
	}
	if x == math.trunc(x) && math.abs(x) < 1e21 {
		return i64(x).str()
	}
	abs := math.abs(x)
	if abs < 1e-6 || abs >= 1e21 {
		return '${x:e}'
	}
	return x.str()
}

fn write_json(value json2.Any, indent string, depth int, mut sb strings.Builder) {
	match value {
		map[string]json2.Any {
			mut keys := value.keys()
			keys.sort()
			sb.write_u8(`{`)
			for i, key in keys {
				if i > 0 {
					sb.write_u8(`,`)
				}
				newline(indent, depth + 1, mut sb)
				write_json_string(key, mut sb)
				sb.write_u8(`:`)
				if indent != '' {
					sb.write_u8(` `)
				}
				write_json(value[key] or { json2.Any(json2.null) }, indent, depth + 1, mut
					sb)
			}
			if keys.len > 0 {
				newline(indent, depth, mut sb)
			}
			sb.write_u8(`}`)
		}
		[]json2.Any {
			sb.write_u8(`[`)
			for i, item in value {
				if i > 0 {
					sb.write_u8(`,`)
				}
				newline(indent, depth + 1, mut sb)
				write_json(item, indent, depth + 1, mut sb)
			}
			if value.len > 0 {
				newline(indent, depth, mut sb)
			}
			sb.write_u8(`]`)
		}
		string {
			write_json_string(value, mut sb)
		}
		bool {
			sb.write_string(if value { 'true' } else { 'false' })
		}
		f64 {
			sb.write_string(format_number(value))
		}
		f32 {
			sb.write_string(format_number(f64(value)))
		}
		int, i64, i32, i16, i8, u64, u32, u16, u8 {
			sb.write_string(value.str())
		}
		json2.Null {
			sb.write_string('null')
		}
		else {
			sb.write_string(value.str())
		}
	}
}

fn write_json_string(s string, mut sb strings.Builder) {
	sb.write_u8(`"`)
	for c in s {
		match c {
			`"` {
				sb.write_string('\\"')
			}
			`\\` {
				sb.write_string('\\\\')
			}
			`\n` {
				sb.write_string('\\n')
			}
			`\r` {
				sb.write_string('\\r')
			}
			`\t` {
				sb.write_string('\\t')
			}
			`<` {
				sb.write_string('\\u003c')
			}
			`>` {
				sb.write_string('\\u003e')
			}
			`&` {
				sb.write_string('\\u0026')
			}
			else {
				if c < 0x20 {
					sb.write_string('\\u${c:04x}')
				} else {
					sb.write_u8(c)
				}
			}
		}
	}
	sb.write_u8(`"`)
}
