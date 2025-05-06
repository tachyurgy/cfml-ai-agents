/**
 * CalculatorTool.cfc
 * Safely evaluate mathematical expressions. Supports basic arithmetic,
 * exponents, modulo, and common math functions.
 */
component extends="models.Tool" accessors="true" {

    public CalculatorTool function init() {
        super.init(
            name = "calculator",
            description = "Evaluate a mathematical expression. Supports: addition (+), subtraction (-), multiplication (*), division (/), exponents (^), modulo (%), parentheses, and functions like sqrt(), abs(), ceiling(), floor(), round(), log(), sin(), cos(), tan(), pi(), min(), max().",
            parameters = {
                "type": "object",
                "properties": {
                    "expression": {
                        "type": "string",
                        "description": "The mathematical expression to evaluate. Examples: '(45 * 12) + 300', 'sqrt(144)', '2^10', 'round(3.14159, 2)'"
                    }
                },
                "required": ["expression"]
            }
        );
        return this;
    }

    public struct function execute(required struct args) {
        var expr = trim(arguments.args.expression);

        if (!len(expr)) {
            return {"result": "Error: Empty expression provided."};
        }

        // Sanitize: only allow safe characters and function names
        var sanitized = lCase(expr);

        // Replace common math notation
        sanitized = replace(sanitized, "^", "**", "all");
        sanitized = replace(sanitized, "pi()", "3.14159265358979", "all");
        sanitized = replace(sanitized, "pi", "3.14159265358979", "all");

        // Whitelist check: only allow digits, operators, parens, dots, commas, spaces, and known functions
        var allowedPattern = "^[\d\s\+\-\*\/\%\.\,\(\)]+$";
        var funcPattern = "(sqrt|abs|ceiling|floor|round|log|log10|sin|cos|tan|asin|acos|atan|exp|min|max|pow|mod)";

        // Remove known function names for the safety check
        var forCheck = reReplaceNoCase(sanitized, funcPattern, "", "all");
        // Also remove ** (exponent operator)
        forCheck = replace(forCheck, "**", "", "all");

        if (!reFind(allowedPattern, trim(forCheck)) && len(trim(forCheck))) {
            return {"result": "Error: Expression contains invalid characters. Only numbers, arithmetic operators (+, -, *, /, ^, %), parentheses, and math functions are allowed."};
        }

        try {
            // Map functions to CFML equivalents and evaluate
            var cfExpr = mapToCFML(sanitized);
            var result = evaluate(cfExpr);

            // Format result nicely
            if (isNumeric(result)) {
                if (result == int(result) && abs(result) < 999999999999) {
                    return {"result": "#int(result)#"};
                }
                return {"result": "#result#"};
            }

            return {"result": "#result#"};

        } catch (any e) {
            return {"result": "Error evaluating expression '#expr#': #e.message#. Check the syntax and try again."};
        }
    }

    /**
     * Map math function names to CFML-compatible syntax.
     */
    private string function mapToCFML(required string expr) {
        var result = arguments.expr;

        // Replace ** with ^ for CFML (or use the pow function)
        // Actually CFML uses ^ for exponents natively
        result = replace(result, "**", "^", "all");

        // Map function names to CFML
        result = reReplaceNoCase(result, "log10\(", "log10(", "all");
        result = reReplaceNoCase(result, "pow\(", "( ", "all"); // handled by ^ operator

        return result;
    }

}
