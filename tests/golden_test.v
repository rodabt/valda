// Golden tests: valda's output must match output recorded from Alda's Go
// client (2.4.7) byte for byte. See testdata/README.md.
import os
import x.json2
import model
import musicxml
import parser

const root = os.dir(os.dir(@FILE))
const golden_dir = os.join_path(root, 'testdata', 'golden')
const examples_dir = os.join_path(root, 'examples')

fn golden_names() []string {
	mut names := os.ls(golden_dir) or { panic(err) }
	names = names.filter(it.ends_with('.events.json')).map(it.all_before('.events.json'))
	names.sort()
	return names
}

fn example(name string) string {
	return os.read_file(os.join_path(examples_dir, name + '.alda')) or { panic(err) }
}

fn golden(name string, suffix string) string {
	return os.read_file(os.join_path(golden_dir, name + suffix)) or { panic(err) }.trim_right('\n')
}

fn test_golden_files_exist() {
	assert golden_names().len >= 10
}

fn test_events_match_alda() {
	for name in golden_names() {
		updates := parser.parse_updates('', example(name)) or { panic('${name}: ${err}') }
		actual := model.encode_json(json2.Any(updates.map(it.json())))
		assert actual == golden(name, '.events.json'), name
	}
}

fn test_score_data_matches_alda() {
	for name in golden_names() {
		updates := parser.parse_updates('', example(name)) or { panic('${name}: ${err}') }
		mut score := model.new_score()
		score.update(...updates) or { panic('${name}: ${err}') }
		assert model.encode_json(score.json()) == golden(name, '.data.json'), name
	}
}

fn test_human_readable_ast_matches_alda() {
	for name in golden_names() {
		path := os.join_path(examples_dir, name + '.alda')
		ast := parser.parse(path, example(name)) or { panic('${name}: ${err}') }
		// The Go client includes the path in source context only for errors, so
		// the AST output doesn't depend on it.
		assert ast.human_readable() == golden(name, '.ast-human.txt'), name
	}
}

fn test_format_matches_alda() {
	for name in golden_names() {
		ast := parser.parse_string(example(name)) or { panic('${name}: ${err}') }
		formatted := parser.format_ast(ast) or { panic('${name}: ${err}') }
		assert formatted.trim_right('\n') == golden(name, '.formatted.alda'), name
	}
}

fn test_formatting_preserves_meaning() {
	for name in golden_names() {
		original := parser.parse_updates('', example(name)) or { panic(err) }
		formatted := parser.format_ast(parser.parse_string(example(name)) or { panic(err) }) or {
			panic(err)
		}
		reparsed := parser.parse_updates('', formatted) or { panic('${name}: ${err}') }

		mut a := model.new_score()
		a.update(...original) or { panic(err) }
		mut b := model.new_score()
		b.update(...reparsed) or { panic(err) }
		assert model.encode_json(json2.Any(a.events.map(it.json()))) == model.encode_json(json2.Any(b.events.map(it.json()))), name
	}
}

fn test_musicxml_import() {
	dir := os.join_path(root, 'testdata', 'musicxml')
	mut files := os.ls(dir) or { panic(err) }
	files = files.filter(it.ends_with('.musicxml'))
	files.sort()
	assert files.len > 20
	for file in files {
		name := file.all_before('.musicxml')
		data := os.read_file(os.join_path(dir, file)) or { panic(err) }
		updates := musicxml.import_musicxml(data) or { panic('${name}: ${err}') }
		root_node := parser.generate_ast(updates) or { panic('${name}: ${err}') }
		text := parser.format_ast(root_node) or { panic('${name}: ${err}') }
		expected := os.read_file(os.join_path(dir, name + '.alda')) or { panic(err) }
		assert text == expected, name

		// The imported Alda code must itself be valid.
		mut score := model.new_score()
		score.update(...parser.parse_updates('', text) or { panic('${name}: ${err}') }) or {
			panic('${name}: ${err}')
		}
	}
}
