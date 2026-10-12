module musicxml

import encoding.xml

// Small helpers giving encoding.xml the subset of etree's API that the
// importer uses. Simple paths like "notations/slur" select child elements.

fn child_elements(node xml.XMLNode) []xml.XMLNode {
	mut result := []xml.XMLNode{}
	for child in node.children {
		if child is xml.XMLNode {
			result << child
		}
	}
	return result
}

// find_elements returns the elements matching a relative path of child tags.
fn find_elements(node xml.XMLNode, path string) []xml.XMLNode {
	mut current := [node]
	for tag in path.split('/') {
		mut next := []xml.XMLNode{}
		for n in current {
			for child in child_elements(n) {
				if child.name == tag {
					next << child
				}
			}
		}
		current = next.clone()
	}
	return current
}

fn find_element(node xml.XMLNode, path string) ?xml.XMLNode {
	found := find_elements(node, path)
	if found.len == 0 {
		return none
	}
	return found[0]
}

// text returns the element's (trimmed) text content.
fn text(node xml.XMLNode) string {
	mut s := ''
	for child in node.children {
		match child {
			string { s += child }
			xml.XMLCData { s += child.text }
			else {}
		}
	}
	return s.trim_space()
}

fn attr(node xml.XMLNode, name string, default_value string) string {
	return node.attributes[name] or { default_value }
}

// strip_doctype removes the <!DOCTYPE ...> declaration, which encoding.xml
// can't parse when it references an external DTD (as MusicXML files do).
fn strip_doctype(s string) string {
	i := s.index('<!DOCTYPE') or { return s }
	mut depth := 0
	for j in i .. s.len {
		c := s[j]
		if c == `[` {
			depth++
		} else if c == `]` {
			depth--
		} else if c == `>` && depth == 0 {
			return s[..i] + s[j + 1..]
		}
	}
	return s
}
