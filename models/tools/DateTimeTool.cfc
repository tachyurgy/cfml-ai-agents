/**
 * DateTimeTool.cfc
 * Date and time operations: get the current time, add/subtract durations,
 * compute differences between dates, and format dates.
 */
component extends="models.Tool" accessors="true" {

    public DateTimeTool function init() {
        super.init(
            name = "datetime",
            description = "Perform date and time operations. Supports: getting the current date/time, adding/subtracting time intervals, calculating differences between dates, and formatting dates. Operations: 'now' (current date/time), 'add' (add interval to date), 'diff' (difference between two dates), 'format' (format a date).",
            parameters = {
                "type": "object",
                "properties": {
                    "operation": {
                        "type": "string",
                        "description": "The operation to perform: 'now', 'add', 'diff', or 'format'",
                        "enum": ["now", "add", "diff", "format"]
                    },
                    "value": {
                        "type": "string",
                        "description": "Operation-specific input. For 'add': '<amount> <unit> [from <date>]' (e.g., '30 days', '2 hours from 2024-01-15'). For 'diff': '<date1> to <date2>' (e.g., '2024-01-01 to 2024-12-31'). For 'format': '<date> as <pattern>' (e.g., '2024-03-15 as MMMM d, yyyy'). Not needed for 'now'."
                    }
                },
                "required": ["operation"]
            }
        );
        return this;
    }

    public struct function execute(required struct args) {
        var operation = lCase(trim(arguments.args.operation));
        var value = structKeyExists(arguments.args, "value") ? trim(arguments.args.value) : "";

        switch (operation) {
            case "now":
                return executeNow();
            case "add":
                return executeAdd(value);
            case "diff":
                return executeDiff(value);
            case "format":
                return executeFormat(value);
            default:
                return {"result": "Unknown operation '#operation#'. Use: now, add, diff, or format."};
        }
    }

    private struct function executeNow() {
        var n = now();
        return {
            "result": "Current date and time: #dateTimeFormat(n, 'yyyy-MM-dd HH:nn:ss')# (Server timezone: #getTimezone()#)#chr(10)#ISO 8601: #dateTimeFormat(n, 'yyyy-MM-dd''T''HH:nn:ssXXX')##chr(10)#Unix timestamp: #dateDiff('s', createDate(1970,1,1), n)##chr(10)#Day of week: #dayOfWeekAsString(dayOfWeek(n))##chr(10)#Week of year: #week(n)#"
        };
    }

    private struct function executeAdd(required string value) {
        if (!len(arguments.value)) {
            return {"result": "Error: The 'add' operation requires a value like '30 days' or '2 hours from 2024-01-15'."};
        }

        // Parse: "<amount> <unit> [from <date>]"
        var baseDate = now();
        var input = arguments.value;

        // Check for "from <date>" clause
        if (reFindNoCase("\bfrom\b", input)) {
            var parts = reMatch("(.+?)\s+from\s+(.+)", input);
            if (reFindNoCase("(.+)\s+from\s+(.+)", input)) {
                var fromIdx = reFindNoCase("\s+from\s+", input);
                var dateStr = trim(mid(input, fromIdx + 5, len(input)));
                input = trim(left(input, fromIdx - 1));
                try {
                    baseDate = parseDateTime(dateStr);
                } catch (any e) {
                    return {"result": "Error: Could not parse date '#dateStr#'. Use formats like 2024-01-15 or January 15, 2024."};
                }
            }
        }

        // Parse amount and unit
        var match = reFind("^(-?\d+)\s*(\w+)", input, 1, true);
        if (match.pos[1] == 0) {
            return {"result": "Error: Could not parse '#input#'. Expected format: '<number> <unit>' (e.g., '30 days', '-2 hours')."};
        }

        var amount = val(mid(input, match.pos[2], match.len[2]));
        var unit = lCase(mid(input, match.pos[3], match.len[3]));

        // Normalize unit names
        var unitMap = {
            "second": "s", "seconds": "s", "sec": "s", "secs": "s", "s": "s",
            "minute": "n", "minutes": "n", "min": "n", "mins": "n", "n": "n",
            "hour": "h", "hours": "h", "hr": "h", "hrs": "h", "h": "h",
            "day": "d", "days": "d", "d": "d",
            "week": "ww", "weeks": "ww", "wk": "ww", "wks": "ww", "ww": "ww",
            "month": "m", "months": "m", "mo": "m", "m": "m",
            "year": "yyyy", "years": "yyyy", "yr": "yyyy", "yrs": "yyyy", "yyyy": "yyyy"
        };

        if (!structKeyExists(unitMap, unit)) {
            return {"result": "Error: Unknown time unit '#unit#'. Use: seconds, minutes, hours, days, weeks, months, or years."};
        }

        var cfUnit = unitMap[unit];
        var resultDate = dateAdd(cfUnit, amount, baseDate);

        return {
            "result": "Base date: #dateTimeFormat(baseDate, 'yyyy-MM-dd HH:nn:ss')##chr(10)#Operation: add #amount# #unit##chr(10)#Result: #dateTimeFormat(resultDate, 'yyyy-MM-dd HH:nn:ss')# (#dayOfWeekAsString(dayOfWeek(resultDate))#)"
        };
    }

    private struct function executeDiff(required string value) {
        if (!len(arguments.value)) {
            return {"result": "Error: The 'diff' operation requires two dates like '2024-01-01 to 2024-12-31'."};
        }

        // Parse: "<date1> to <date2>"
        var toIdx = reFindNoCase("\s+to\s+", arguments.value);
        if (toIdx == 0) {
            return {"result": "Error: Use format '<date1> to <date2>' (e.g., '2024-01-01 to 2024-12-31')."};
        }

        var dateStr1 = trim(left(arguments.value, toIdx - 1));
        var dateStr2 = trim(mid(arguments.value, toIdx + 3, len(arguments.value)));

        try {
            var date1 = parseDateTime(dateStr1);
        } catch (any e) {
            return {"result": "Error: Could not parse date '#dateStr1#'."};
        }

        try {
            var date2 = parseDateTime(dateStr2);
        } catch (any e) {
            return {"result": "Error: Could not parse date '#dateStr2#'."};
        }

        var diffDays = dateDiff("d", date1, date2);
        var diffHours = dateDiff("h", date1, date2);
        var diffWeeks = dateDiff("ww", date1, date2);
        var diffMonths = dateDiff("m", date1, date2);
        var diffYears = dateDiff("yyyy", date1, date2);

        return {
            "result": "From: #dateFormat(date1, 'yyyy-MM-dd')# (#dayOfWeekAsString(dayOfWeek(date1))#)#chr(10)#To: #dateFormat(date2, 'yyyy-MM-dd')# (#dayOfWeekAsString(dayOfWeek(date2))#)#chr(10)##chr(10)#Difference:#chr(10)#  #abs(diffDays)# days#chr(10)#  #abs(diffWeeks)# weeks#chr(10)#  #abs(diffMonths)# months#chr(10)#  #abs(diffYears)# years#chr(10)#  #abs(diffHours)# hours"
        };
    }

    private struct function executeFormat(required string value) {
        if (!len(arguments.value)) {
            return {"result": "Error: The 'format' operation requires input like '2024-03-15 as MMMM d, yyyy'."};
        }

        var asIdx = reFindNoCase("\s+as\s+", arguments.value);
        var dateStr = "";
        var pattern = "yyyy-MM-dd HH:nn:ss";

        if (asIdx > 0) {
            dateStr = trim(left(arguments.value, asIdx - 1));
            pattern = trim(mid(arguments.value, asIdx + 3, len(arguments.value)));
        } else {
            dateStr = arguments.value;
        }

        try {
            var d = parseDateTime(dateStr);
            return {
                "result": "#dateTimeFormat(d, pattern)#"
            };
        } catch (any e) {
            return {"result": "Error: Could not parse or format date '#dateStr#' with pattern '#pattern#'. #e.message#"};
        }
    }

    private string function getTimezone() {
        try {
            return createObject("java", "java.util.TimeZone").getDefault().getID();
        } catch (any e) {
            return "Unknown";
        }
    }

}
