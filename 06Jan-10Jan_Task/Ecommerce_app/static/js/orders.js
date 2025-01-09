document.addEventListener("DOMContentLoaded", () => {
    const loadingEl = document.getElementById("loading");
    const errorEl = document.getElementById("error");
    const containerEl = document.getElementById("orders-container");

    async function loadOrders() {
        try {
            loadingEl.style.display = "block";
            errorEl.style.display = "none";
            containerEl.innerHTML = "";

            const response = await fetch("/api/orders");
            const data = await response.json();

            if (!data.success) {
                throw new Error(data.error || "Failed to load orders");
            }

            if (data.orders.length === 0) {
                containerEl.innerHTML = "<p class=\"no-orders\">No orders found</p>";
                return;
            }

            const table = document.createElement("table");
            table.className = "orders-table";
            table.innerHTML = `
                <thead>
                    <tr>
                        <th>Order ID</th>
                        <th>Product</th>
                        <th>Quantity</th>
                        <th>Unit Price</th>
                        <th>Total Price</th>
                        <th>Status</th>
                        <th>Date</th>
                    </tr>
                </thead>
                <tbody>
                    ${data.orders.map(order => `
                        <tr>
                            <td>${order.id}</td>
                            <td>${order.product_name}</td>
                            <td>${order.quantity}</td>
                            <td>$${order.unit_price.toFixed(2)}</td>
                            <td>$${order.total_price.toFixed(2)}</td>
                            <td>${order.status}</td>
                            <td>${new Date(order.created_at).toLocaleString()}</td>
                        </tr>
                    `).join("")}
                </tbody>
            `;
            containerEl.appendChild(table);
        } catch (error) {
            errorEl.textContent = error.message;
            errorEl.style.display = "block";
        } finally {
            loadingEl.style.display = "none";
        }
    }

    loadOrders();
});
