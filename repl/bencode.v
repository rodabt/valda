module repl

import io
import strings
import x.json2

// Bencode, the wire format of the nREPL protocol.

pub type BValue = []BValue | i64 | map[string]BValue | string

pub fn bencode(value BValue) string {
	mut sb := strings.new_builder(256)
	write_bvalue(value, mut sb)
	return sb.str()
}

fn write_bvalue(value BValue, mut sb strings.Builder) {
	match value {
		string {
			sb.write_string('${value.len}:')
			sb.write_string(value)
		}
		i64 {
			sb.write_string('i${value}e')
		}
		[]BValue {
			sb.write_u8(`l`)
			for item in value {
				write_bvalue(item, mut sb)
			}
			sb.write_u8(`e`)
		}
		map[string]BValue {
			sb.write_u8(`d`)
			mut keys := value.keys()
			keys.sort()
			for key in keys {
				write_bvalue(key, mut sb)
				write_bvalue(value[key] or { BValue('') }, mut sb)
			}
			sb.write_u8(`e`)
		}
	}
}

// BReader decodes bencoded values from a stream.
pub struct BReader {
mut:
	reader io.Reader
	buf    []u8 = []u8{len: 4096}
	pos    int
	len    int
}

pub fn new_breader(reader io.Reader) BReader {
	return BReader{
		reader: reader
	}
}

fn (mut r BReader) next_byte() !u8 {
	if r.pos >= r.len {
		n := r.reader.read(mut r.buf)!
		if n <= 0 {
			return io.Eof{}
		}
		r.pos = 0
		r.len = n
	}
	b := r.buf[r.pos]
	r.pos++
	return b
}

fn (mut r BReader) peek_byte() !u8 {
	b := r.next_byte()!
	r.pos--
	return b
}

fn (mut r BReader) read_until(terminator u8) !string {
	mut sb := strings.new_builder(16)
	for {
		b := r.next_byte()!
		if b == terminator {
			break
		}
		sb.write_u8(b)
	}
	return sb.str()
}

// decode reads one bencoded value.
pub fn (mut r BReader) decode() !BValue {
	b := r.next_byte()!
	match b {
		`i` {
			return r.read_until(`e`)!.i64()
		}
		`l` {
			mut items := []BValue{}
			for r.peek_byte()! != `e` {
				items << r.decode()!
			}
			r.next_byte()!
			return items
		}
		`d` {
			mut m := map[string]BValue{}
			for r.peek_byte()! != `e` {
				key := r.decode()!
				if key !is string {
					return error('bencode: dictionary key is not a string')
				}
				m[key as string] = r.decode()!
			}
			r.next_byte()!
			return m
		}
		`0`...`9` {
			length := (b.ascii_str() + r.read_until(`:`)!).int()
			mut data := []u8{cap: length}
			for _ in 0 .. length {
				data << r.next_byte()!
			}
			return data.bytestr()
		}
		else {
			return error('bencode: unexpected byte ${b}')
		}
	}
}

// Conversions between JSON and bencode values, for `repl --message`.

pub fn json_to_bvalue(value json2.Any) BValue {
	match value {
		string {
			return BValue(value)
		}
		[]json2.Any {
			return BValue(value.map(json_to_bvalue(it)))
		}
		map[string]json2.Any {
			mut m := map[string]BValue{}
			for k, v in value {
				m[k] = json_to_bvalue(v)
			}
			return BValue(m)
		}
		else {}
	}
	if value is bool {
		return BValue(i64(int(value)))
	}
	return BValue(value.i64())
}

pub fn bvalue_to_json(value BValue) json2.Any {
	return match value {
		string {
			json2.Any(value)
		}
		i64 {
			json2.Any(value)
		}
		[]BValue {
			json2.Any(value.map(bvalue_to_json(it)))
		}
		map[string]BValue {
			mut m := map[string]json2.Any{}
			for k, v in value {
				m[k] = bvalue_to_json(v)
			}
			json2.Any(m)
		}
	}
}
