/**
 * DatabaseQueryTool.cfc
 * Execute read-only SQL queries against an in-memory H2 demo database.
 * The database is initialized with sample data on first use.
 */
component extends="models.Tool" accessors="true" {

    property name="dsn" type="string" default="cfml_agents_demo";
    property name="initialized" type="boolean" default=false;

    public DatabaseQueryTool function init() {
        super.init(
            name = "query_database",
            description = "Execute a read-only SQL query against the demo database. The database contains sample tables: products (id, name, category, price, stock), customers (id, name, email, city, signup_date), and orders (id, customer_id, product_id, quantity, order_date, total). Only SELECT statements are allowed.",
            parameters = {
                "type": "object",
                "properties": {
                    "sql": {
                        "type": "string",
                        "description": "A SQL SELECT query to execute. Only read operations are permitted."
                    }
                },
                "required": ["sql"]
            }
        );

        variables.initialized = false;
        return this;
    }

    public struct function execute(required struct args) {
        var sql = trim(arguments.args.sql);

        // Safety check: only allow SELECT statements
        var normalizedSql = uCase(trim(reReplace(sql, "\s+", " ", "all")));
        if (!reFindNoCase("^\s*SELECT", normalizedSql)) {
            return {
                "result": "Error: Only SELECT queries are allowed. Write operations (INSERT, UPDATE, DELETE, DROP, ALTER, CREATE) are blocked for safety."
            };
        }

        // Block dangerous patterns
        var blocked = "INSERT |UPDATE |DELETE |DROP |ALTER |CREATE |TRUNCATE |GRANT |EXEC |EXECUTE |INTO ";
        if (reFindNoCase(blocked, normalizedSql)) {
            return {
                "result": "Error: This query contains blocked SQL keywords. Only pure SELECT queries are allowed."
            };
        }

        // Initialize demo database if needed
        if (!variables.initialized) {
            try {
                initDemoDatabase();
            } catch (any e) {
                return {
                    "result": "Database not available: #e.message#. The demo database requires a Lucee server with H2 support. When running locally, ensure the server is started with CommandBox or Docker."
                };
            }
        }

        try {
            var q = queryExecute(sql, {}, {datasource: variables.dsn});

            if (q.recordCount == 0) {
                return {"result": "Query returned 0 rows."};
            }

            // Convert query to array of structs
            var rows = [];
            var cols = listToArray(q.columnList);
            for (var row in q) {
                var r = {};
                for (var col in cols) {
                    r[lCase(col)] = row[col];
                }
                arrayAppend(rows, r);
            }

            // Truncate if too many rows
            var resultText = "Returned #q.recordCount# row(s).#chr(10)#";
            if (q.recordCount > 50) {
                resultText &= "(Showing first 50 of #q.recordCount#)#chr(10)#";
                rows = arraySlice(rows, 1, 50);
            }
            resultText &= serializeJSON(rows);

            return {"result": resultText};

        } catch (any e) {
            return {
                "result": "SQL Error: #e.message#. Check your query syntax and table/column names. Available tables: products, customers, orders."
            };
        }
    }

    /**
     * Initialize the in-memory demo database with sample tables and data.
     */
    private void function initDemoDatabase() {
        // Create datasource dynamically if it doesn't exist (Lucee-specific)
        try {
            var adminApi = createObject("component", "lucee.admin").init("web");
        } catch (any e) {
            // If we can't create the datasource programmatically, just set the flag
            // and let the query fail with a meaningful error
        }

        // Try to create tables (they may already exist)
        try {
            queryExecute("
                CREATE TABLE IF NOT EXISTS products (
                    id INT PRIMARY KEY AUTO_INCREMENT,
                    name VARCHAR(200) NOT NULL,
                    category VARCHAR(100),
                    price DECIMAL(10,2),
                    stock INT DEFAULT 0
                )
            ", {}, {datasource: variables.dsn});

            queryExecute("
                CREATE TABLE IF NOT EXISTS customers (
                    id INT PRIMARY KEY AUTO_INCREMENT,
                    name VARCHAR(200) NOT NULL,
                    email VARCHAR(200),
                    city VARCHAR(100),
                    signup_date DATE
                )
            ", {}, {datasource: variables.dsn});

            queryExecute("
                CREATE TABLE IF NOT EXISTS orders (
                    id INT PRIMARY KEY AUTO_INCREMENT,
                    customer_id INT,
                    product_id INT,
                    quantity INT DEFAULT 1,
                    order_date DATE,
                    total DECIMAL(10,2)
                )
            ", {}, {datasource: variables.dsn});

            // Insert sample data (only if tables are empty)
            var check = queryExecute("SELECT COUNT(*) as cnt FROM products", {}, {datasource: variables.dsn});
            if (check.cnt == 0) {
                seedData();
            }

            variables.initialized = true;
        } catch (any e) {
            rethrow;
        }
    }

    private void function seedData() {
        var products = [
            {n: "Wireless Keyboard", c: "Electronics", p: 59.99, s: 142},
            {n: "Standing Desk", c: "Furniture", p: 449.00, s: 38},
            {n: "Noise-Canceling Headphones", c: "Electronics", p: 279.99, s: 67},
            {n: "Ergonomic Mouse", c: "Electronics", p: 39.99, s: 215},
            {n: "Monitor Arm", c: "Furniture", p: 89.99, s: 93},
            {n: "Webcam HD Pro", c: "Electronics", p: 129.99, s: 56},
            {n: "Desk Lamp LED", c: "Furniture", p: 44.99, s: 178},
            {n: "USB-C Hub", c: "Electronics", p: 69.99, s: 324},
            {n: "Laptop Stand", c: "Furniture", p: 34.99, s: 201},
            {n: "Mechanical Keyboard", c: "Electronics", p: 149.99, s: 89}
        ];

        for (var p in products) {
            queryExecute(
                "INSERT INTO products (name, category, price, stock) VALUES (:name, :cat, :price, :stock)",
                {name: p.n, cat: p.c, price: p.p, stock: p.s},
                {datasource: variables.dsn}
            );
        }

        var customers = [
            {n: "Alice Chen", e: "alice@example.com", c: "Seattle", d: "2024-01-15"},
            {n: "Bob Martinez", e: "bob@example.com", c: "Austin", d: "2024-02-20"},
            {n: "Carol Johnson", e: "carol@example.com", c: "Denver", d: "2024-03-10"},
            {n: "Dave Kim", e: "dave@example.com", c: "Portland", d: "2024-04-05"},
            {n: "Eve Williams", e: "eve@example.com", c: "Chicago", d: "2024-05-18"},
            {n: "Frank Garcia", e: "frank@example.com", c: "Miami", d: "2024-06-22"},
            {n: "Grace Lee", e: "grace@example.com", c: "New York", d: "2024-07-30"},
            {n: "Hank Brown", e: "hank@example.com", c: "Seattle", d: "2024-08-14"}
        ];

        for (var cust in customers) {
            queryExecute(
                "INSERT INTO customers (name, email, city, signup_date) VALUES (:name, :email, :city, :sdate)",
                {name: cust.n, email: cust.e, city: cust.c, sdate: cust.d},
                {datasource: variables.dsn}
            );
        }

        var orders = [
            {ci: 1, pi: 3, q: 1, d: "2024-09-01", t: 279.99},
            {ci: 1, pi: 8, q: 2, d: "2024-09-01", t: 139.98},
            {ci: 2, pi: 2, q: 1, d: "2024-09-05", t: 449.00},
            {ci: 3, pi: 1, q: 1, d: "2024-09-10", t: 59.99},
            {ci: 3, pi: 4, q: 1, d: "2024-09-10", t: 39.99},
            {ci: 4, pi: 6, q: 1, d: "2024-09-15", t: 129.99},
            {ci: 5, pi: 10, q: 1, d: "2024-09-20", t: 149.99},
            {ci: 5, pi: 5, q: 2, d: "2024-09-20", t: 179.98},
            {ci: 6, pi: 7, q: 3, d: "2024-09-25", t: 134.97},
            {ci: 7, pi: 9, q: 1, d: "2024-09-28", t: 34.99},
            {ci: 7, pi: 1, q: 1, d: "2024-09-28", t: 59.99},
            {ci: 8, pi: 2, q: 1, d: "2024-10-01", t: 449.00},
            {ci: 1, pi: 10, q: 1, d: "2024-10-05", t: 149.99},
            {ci: 2, pi: 4, q: 2, d: "2024-10-10", t: 79.98},
            {ci: 4, pi: 3, q: 1, d: "2024-10-15", t: 279.99}
        ];

        for (var o in orders) {
            queryExecute(
                "INSERT INTO orders (customer_id, product_id, quantity, order_date, total) VALUES (:ci, :pi, :q, :od, :t)",
                {ci: o.ci, pi: o.pi, q: o.q, od: o.d, t: o.t},
                {datasource: variables.dsn}
            );
        }
    }

}
