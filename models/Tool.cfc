/**
 * Tool.cfc
 * Base component for all agent tools. Extend this to create custom tools.
 * Each tool has a name, description, and JSON Schema parameters definition.
 */
component accessors="true" {

    property name="name" type="string" default="";
    property name="description" type="string" default="";
    property name="parameters" type="struct";

    public Tool function init(
        string name = "",
        string description = "",
        struct parameters = {}
    ) {
        variables.name = arguments.name;
        variables.description = arguments.description;
        variables.parameters = arguments.parameters;
        return this;
    }

    /**
     * Execute the tool with the given arguments.
     * Override this method in subclasses.
     * @args Struct of arguments matching the parameters schema.
     * @return Struct with at minimum a "result" key.
     */
    public struct function execute(required struct args) {
        throw(
            type = "Tool.NotImplemented",
            message = "Tool '#variables.name#' has not implemented the execute() method."
        );
    }

    /**
     * Returns the tool definition in the format expected by the LLM.
     */
    public struct function getSchema() {
        return {
            "name": variables.name,
            "description": variables.description,
            "parameters": variables.parameters
        };
    }

    /**
     * Validate arguments against the parameter schema.
     * Returns a struct with "valid" (boolean) and "errors" (array).
     */
    public struct function validate(required struct args) {
        var result = {"valid": true, "errors": []};
        var schema = variables.parameters;

        // Check required properties
        if (structKeyExists(schema, "required") && isArray(schema.required)) {
            for (var reqField in schema.required) {
                if (!structKeyExists(arguments.args, reqField) || (isSimpleValue(arguments.args[reqField]) && !len(trim(arguments.args[reqField])))) {
                    result.valid = false;
                    arrayAppend(result.errors, "Missing required parameter: #reqField#");
                }
            }
        }

        // Check types for provided properties
        if (structKeyExists(schema, "properties") && isStruct(schema.properties)) {
            for (var propName in arguments.args) {
                if (structKeyExists(schema.properties, propName) && structKeyExists(schema.properties[propName], "type")) {
                    var expectedType = schema.properties[propName].type;
                    var val = arguments.args[propName];

                    switch (expectedType) {
                        case "string":
                            if (!isSimpleValue(val)) {
                                result.valid = false;
                                arrayAppend(result.errors, "Parameter '#propName#' must be a string.");
                            }
                            break;
                        case "number": case "integer":
                            if (!isNumeric(val)) {
                                result.valid = false;
                                arrayAppend(result.errors, "Parameter '#propName#' must be a number.");
                            }
                            break;
                        case "boolean":
                            if (!isBoolean(val)) {
                                result.valid = false;
                                arrayAppend(result.errors, "Parameter '#propName#' must be a boolean.");
                            }
                            break;
                        case "array":
                            if (!isArray(val)) {
                                result.valid = false;
                                arrayAppend(result.errors, "Parameter '#propName#' must be an array.");
                            }
                            break;
                        case "object":
                            if (!isStruct(val)) {
                                result.valid = false;
                                arrayAppend(result.errors, "Parameter '#propName#' must be an object.");
                            }
                            break;
                    }
                }
            }
        }

        return result;
    }

}
