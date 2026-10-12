module model

// AldaSourceContext provides some context about the origin of an error in an
// Alda source file.
pub struct AldaSourceContext {
pub:
	filename string
	line     int
	column   int
}

// AldaSourceError wraps an underlying error to provide context about the Alda
// source file from which the error originated.
pub struct AldaSourceError {
	Error
pub:
	context AldaSourceContext
	err     IError = none
}

// msg unwraps nested AldaSourceErrors until reaching the bottom-most one, and
// reports the deepest source context that was available along the way.
pub fn (e AldaSourceError) msg() string {
	mut filename := ''
	mut line := 0
	mut column := 0
	mut bottom := e
	mut current := IError(e)

	for {
		if mut current is AldaSourceError {
			bottom = *current
			if bottom.context.line != 0 {
				filename = bottom.context.filename
				line = bottom.context.line
				column = bottom.context.column
			}
			current = bottom.err
			continue
		}
		break
	}

	if filename == '' {
		filename = '<no file>'
	}

	return '${filename}:${line}:${column} ${bottom.err.msg()}'
}

// source_error wraps an error with source context.
pub fn source_error(context AldaSourceContext, err IError) IError {
	return IError(AldaSourceError{
		context: context
		err:     err
	})
}

// source_errorf creates a new error with source context.
pub fn source_errorf(context AldaSourceContext, msg string) IError {
	return source_error(context, error(msg))
}
