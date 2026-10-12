module repl

import io

struct StringReader {
	data string
mut:
	pos int
}

fn (mut r StringReader) read(mut buf []u8) !int {
	if r.pos >= r.data.len {
		return io.Eof{}
	}
	n := copy(mut buf, r.data[r.pos..].bytes())
	r.pos += n
	return n
}

fn test_encode() {
	assert bencode('spam') == '4:spam'
	assert bencode(i64(-42)) == 'i-42e'
	assert bencode([BValue('a'), i64(1)]) == 'l1:ai1ee'
	assert bencode({
		'op':   BValue('eval')
		'code': BValue('c d')
	}) == 'd4:code3:c d2:op4:evale'
}

fn test_round_trip() {
	value := BValue({
		'op':     BValue('describe')
		'nested': BValue([BValue(i64(7)), BValue({
			'k': BValue('v')
		})])
		'binary': BValue([u8(0), 255, 10].bytestr())
	})
	mut reader := new_breader(StringReader{
		data: bencode(value) + bencode('second')
	})
	assert bencode(reader.decode()!) == bencode(value)
	assert reader.decode()! == BValue('second')
	if _ := reader.decode() {
		assert false
	}
}

fn test_server_ops() {
	mut server := new_server(false)
	res := server.handle({
		'op':   BValue('load')
		'code': BValue('piano: c d e')
		'id':   BValue('1')
	})
	assert res['status']! == BValue([BValue('done')])
	assert res['id']! == BValue('1')

	text := server.handle({
		'op': BValue('score-text')
	})
	assert text['text']! == BValue('piano: c d e\n')

	exported := server.handle({
		'op': BValue('export')
	})
	assert (exported['binary-data']! as string).starts_with('MThd')

	// Without audio, playing is an error.
	play := server.handle({
		'op':   BValue('eval-and-play')
		'code': BValue('f')
	})
	assert response_errors(play)[0].contains('audio output is not available')

	unknown := server.handle({
		'op': BValue('nope')
	})
	assert unknown['status']! == BValue([BValue('done'), BValue('error'), BValue('unknown-op')])
}
