document.addEventListener("DOMContentLoaded", () => {
    const loadingEl = document.getElementById("loading");
    const errorEl = document.getElementById("error");
    const successEl = document.getElementById("success");
    const containerEl = document.getElementById("products-container");

    async function buyProduct(productId) {
        try {
            const response = await fetch("/api/orders", {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                },
                body: JSON.stringify({
                    product_id: productId,
                    quantity: 1,
                }),
            });

            const data = await response.json();

            if (!data.success) {
                throw new Error(data.error || "Failed to place order");
            }

            successEl.textContent = `Order placed successfully! Total: $${data.total_price.toFixed(2)}`;
            successEl.style.display = "block";
            setTimeout(() => {
                successEl.style.display = "none";
            }, 3000);

        } catch (error) {
            errorEl.textContent = error.message;
            errorEl.style.display = "block";
            setTimeout(() => {
                errorEl.style.display = "none";
            }, 3000);
        }
    }

    async function loadProducts() {
        try {
            loadingEl.style.display = "block";
            errorEl.style.display = "none";
            containerEl.innerHTML = "";

            const response = await fetch("/api/products");
            const data = await response.json();

            if (!data.success) {
                throw new Error(data.error || "Failed to load products");
            }

            data.products.forEach(product => {
                const productCard = document.createElement("div");
                productCard.className = "product-card";
                productCard.innerHTML = `
                    <img src="${product.image_url}" alt="${product.name}" class="product-image">
                    <h2>${product.name}</h2>
                    <p class="price">$${product.price.toFixed(2)}</p>
                    <p class="description">${product.description}</p>
                    <button class="buy-button" onclick="buyProduct(${product.id})">Buy Now</button>
                `;
                containerEl.appendChild(productCard);
            });
        } catch (error) {
            errorEl.textContent = error.message;
            errorEl.style.display = "block";
        } finally {
            loadingEl.style.display = "none";
        }
    }

    window.buyProduct = buyProduct;
    loadProducts();
});
