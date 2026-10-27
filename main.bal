import ballerina/mcp;

configurable int port = 9090;

// Mock data. Replace with calls to the real order system.
type Order record {|
    readonly string orderId;
    string status;
    string item;
    string estimatedDelivery;
|};

isolated table<Order> key(orderId) orders = table [
    {orderId: "ORD-1001", status: "Shipped", item: "Wireless Headphones", estimatedDelivery: "2026-10-29"},
    {orderId: "ORD-1002", status: "Processing", item: "Mechanical Keyboard", estimatedDelivery: "2026-11-03"},
    {orderId: "ORD-1003", status: "Delivered", item: "USB-C Hub", estimatedDelivery: "2026-10-20"}
];

listener mcp:StreamableHttpListener mcpListener = check new (port);

@mcp:StreamableHttpServiceConfig {
    info: {name: "Orders MCP Server", version: "1.0.0"},
    // No per-client state, so each request stands alone. Simplest to run behind gateways.
    sessionMode: mcp:STATELESS
}
isolated service mcp:StreamableHttpService /mcp on mcpListener {

    # Looks up the current status of a customer order.
    #
    # + orderId - The order ID, for example ORD-1001
    # + return - Order details, or a message if the order is not found
    remote function getOrderStatus(string orderId) returns Order|string {
        string id = orderId.trim().toUpperAscii();
        lock {
            Order? 'order = orders[id];
            return 'order is Order ? 'order.clone() : string `No order found with ID ${id}.`;
        }
    }

    # Cancels a customer order. Only orders that have not shipped yet (status Processing) can be cancelled.
    #
    # + orderId - The order ID, for example ORD-1002
    # + return - The updated order, or a message explaining why it could not be cancelled
    remote function cancelOrder(string orderId) returns Order|string {
        string id = orderId.trim().toUpperAscii();
        lock {
            Order? 'order = orders[id];
            if 'order is () {
                return string `No order found with ID ${id}.`;
            }
            if 'order.status != "Processing" {
                return string `Order ${id} cannot be cancelled because it is already ${'order.status}.`;
            }
            'order.status = "Cancelled";
            return 'order.clone();
        }
    }
}
