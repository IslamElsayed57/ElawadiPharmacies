
// ============================================================
// Supabase Connection
// ============================================================

const SUPABASE_URL = "https://lbjeykexbkhyvuafndjr.supabase.co";

const SUPABASE_PUBLISHABLE_KEY = "sb_publishable_wXSSlFYiiq5JseRoTyvFmw_M2O5PEiU";

const supabaseClient = window.supabase.createClient(
    SUPABASE_URL,
    SUPABASE_PUBLISHABLE_KEY
);

/**
 * Uploads a prescription file to the "prescriptions" Storage bucket
 * and returns its public URL, or null if no file / upload failed.
 */
async function uploadPrescriptionFile(file) {
    if (!file) return null;

    try {
        const fileExt = file.name.split(".").pop();
        const safeName = `${Date.now()}_${Math.floor(Math.random() * 100000)}.${fileExt}`;

        const { error: uploadError } = await supabaseClient
            .storage
            .from("prescriptions")
            .upload(safeName, file, {
                cacheControl: "3600",
                upsert: false
            });

        if (uploadError) {
            console.error("Prescription upload error:", uploadError);
            return null;
        }

        const { data: publicUrlData } = supabaseClient
            .storage
            .from("prescriptions")
            .getPublicUrl(safeName);

        return publicUrlData?.publicUrl || null;

    } catch (err) {
        console.error("Unexpected prescription upload error:", err);
        return null;
    }
}
/**
 * ==========================================================================
 * صيدليات العوضي (Elawadi Pharmacies) - Main JavaScript
 * Pure Vanilla JS (ES6+) - No Frameworks
 * ==========================================================================
 */

// --------------------------------------------------------------------------
// 1. Data Store: Products Catalog & Branches
// --------------------------------------------------------------------------
let PRODUCTS_DATA = [];
let CATEGORIES_DATA = [];
let SUBCATEGORIES_DATA = [];

/**
 * Fetches active categories and products from Supabase and builds
 * PRODUCTS_DATA in the same shape the rest of the app already expects,
 * then triggers the first catalog render. Called once on page load.
 */
/**
 * Groups fetched subcategories by their parent category's slug, then
 * replaces the static hardcoded links inside each category's
 * .subcat-dropdown-menu with real, database-driven ones. Falls back to
 * hiding the dropdown entirely for a category that has no subcategories.
 */
function renderSubcategoryDropdowns(categoryMap) {
    const bySlug = {};
    SUBCATEGORIES_DATA.forEach(s => {
        const cat = categoryMap[s.category_id];
        if (!cat) return;
        if (!bySlug[cat.slug]) bySlug[cat.slug] = [];
        bySlug[cat.slug].push(s);
    });

    document.querySelectorAll(".cat-item-wrapper").forEach(wrapper => {
        const pillBtn = wrapper.querySelector(".cat-pill");
        const menu = wrapper.querySelector(".subcat-dropdown-menu");
        const grid = wrapper.querySelector(".subcat-grid");
        if (!pillBtn || !menu || !grid) return;

        const slug = pillBtn.getAttribute("data-category");
        const list = bySlug[slug] || [];

        if (list.length === 0) {
            menu.style.display = "none";
            return;
        }

        menu.style.display = "";
        grid.innerHTML = list.map(s => `
            <a href="javascript:void(0)" class="subcat-link"
                onclick="filterBySubcategoryId('${slug}', '${s.id}', '${(s.name_ar || "").replace(/'/g, "\\'")}')">
                <i class="fa-solid ${s.icon || 'fa-pills'}"></i>
                <div><strong>${s.name_ar}</strong></div>
            </a>
        `).join("");
    });
}

async function loadProductsCatalog() {
    try {
        const { data: categories, error: catError } = await supabaseClient
            .from("categories")
            .select("id, name_ar, slug")
            .eq("is_active", true);

        if (catError) throw catError;

        CATEGORIES_DATA = categories || [];

        const categoryMap = {};
        CATEGORIES_DATA.forEach(c => {
            categoryMap[c.id] = { slug: c.slug, name_ar: c.name_ar };
        });

        // Fetch active subcategories and render them into each category's
        // dropdown menu live, instead of the old hardcoded keyword list.
        const { data: subcats, error: subError } = await supabaseClient
            .from("subcategories")
            .select("id, category_id, name_ar, name_en, icon")
            .eq("is_active", true);

        if (subError) throw subError;

        SUBCATEGORIES_DATA = subcats || [];
        renderSubcategoryDropdowns(categoryMap);

        const { data: products, error: prodError } = await supabaseClient
            .from("products")
            .select("*")
            .eq("is_active", true)
            .order("created_at", { ascending: false });

        if (prodError) throw prodError;

        PRODUCTS_DATA = (products || []).map(p => {
            const cat = categoryMap[p.category_id] || {};
            return {
                id: p.id,
                nameAr: p.name_ar || "",
                nameEn: p.name_en || "",
                category: cat.slug || "medicines",
                categoryName: cat.name_ar || "",
                price: Number(p.price) || 0,
                oldPrice: p.old_price ? Number(p.old_price) : null,
                badge: p.badge || "",
                badgeType: p.badge_type || "official",
                icon: p.icon || "fa-pills",
                imageUrl: p.image_url || null,
                inStock: p.in_stock !== false,
                subcategoryId: p.subcategory_id || null
            };
        });

        renderProductsCatalog();

    } catch (err) {
        console.error("Load products catalog error:", err);
        const grid = document.getElementById("productsCatalogGrid");
        if (grid) {
            grid.innerHTML = `
                <div style="text-align:center; padding:3rem 1rem; color:#EF4444;">
                    <i class="fa-solid fa-triangle-exclamation" style="font-size:2rem; margin-bottom:0.75rem;"></i>
                    <p>تعذر تحميل قائمة الأدوية والمنتجات حالياً. برجاء تحديث الصفحة أو المحاولة لاحقاً.</p>
                </div>
            `;
        }
    }
}

const BRANCHES_DATA = {
    dakahlia: [
        {
            name: "فرع طناح - المنصورة - الدقهلية",
            address: "الشارع الرئيسي - بجوار المجمع الطبي، طناح، مركز المنصورة، الدقهلية",
            phone: "050-2450001",
            hours: "24 ساعة يومياً (خدمة التوصيل متاحة)",
            manager: "د. إسلام السيد"
        },
        {
            name: "فرع كفر طناح - المنصورة - الدقهلية",
            address: "طريق كفر طناح الرئيسي - أمام المسجد الكبير، كفر طناح، المنصورة، الدقهلية",
            phone: "050-2450002",
            hours: "24 ساعة يومياً (خدمة التوصيل متاحة)",
            manager: "د. أحمد العوضي"
        }
    ]
};

// --------------------------------------------------------------------------
// 2. Application State
// --------------------------------------------------------------------------
let state = {
    currentCategory: "all",
    activeSubcategory: null,
    activeSubcategoryId: null,
    searchQuery: "",
    inlineSearchQuery: "",
    sortBy: "featured",
    cart: []
};

// --------------------------------------------------------------------------
// 3. App Initialization
// --------------------------------------------------------------------------
document.addEventListener("DOMContentLoaded", () => {
    setupThemeToggle();

    // Initial products render (fetched live from Supabase)
    loadProductsCatalog();

    // Initial branches render
    showBranchCity("dakahlia");

    // Populate clinic branch dropdown
    populateClinicBranchOptions();

    // Initial doctor slots render (also populates doctor list for the default branch)
    onDoctorSelectChange("أ.د. شريف عبد الرحمن");

    // Check URL hash for routing
    handleInitialRouting();

    // Setup global search live listener
    setupGlobalSearchListeners();
});

// --------------------------------------------------------------------------
// 3.1 Theme (light / dark mode)
// --------------------------------------------------------------------------
function setupThemeToggle() {
    const savedTheme = localStorage.getItem("elawadi_theme") || localStorage.getItem("elawadi-theme");
    const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
    applyTheme(savedTheme === "dark" || (!savedTheme && prefersDark));
}

function toggleTheme() {
    const isDark = !document.body.classList.contains("dark-mode");
    applyTheme(isDark);
    localStorage.setItem("elawadi-theme", isDark ? "dark" : "light");
    localStorage.setItem("elawadi_theme", isDark ? "dark" : "light");
}

function applyTheme(isDark) {
    const toggle = document.getElementById("themeToggle");
    document.body.classList.toggle("dark-mode", isDark);

    if (!toggle) return;

    toggle.setAttribute("aria-pressed", String(isDark));
    toggle.setAttribute("aria-label", isDark ? "تفعيل الوضع النهاري" : "تفعيل الوضع الليلي");
    toggle.innerHTML = isDark
        ? '<i class="fa-solid fa-sun" aria-hidden="true"></i><span>الوضع النهاري</span>'
        : '<i class="fa-solid fa-moon" aria-hidden="true"></i><span>الوضع الليلي</span>';
}

// --------------------------------------------------------------------------
// 4. Navigation & Section Switching
// --------------------------------------------------------------------------
function switchSection(sectionId) {
    const sections = document.querySelectorAll(".app-section");
    const navLinks = document.querySelectorAll(".nav-link");

    // Update section active state
    sections.forEach(sec => {
        if (sec.id === `section-${sectionId}`) {
            sec.classList.add("active");
        } else {
            sec.classList.remove("active");
        }
    });

    // Update nav links active state
    navLinks.forEach(link => {
        if (link.getAttribute("data-section") === sectionId) {
            link.classList.add("active");
        } else {
            link.classList.remove("active");
        }
    });

    // Close mobile menu if opened
    const mainNav = document.getElementById("mainNav");
    if (mainNav.classList.contains("mobile-active")) {
        mainNav.classList.remove("mobile-active");
    }

    // Scroll to top
    window.scrollTo({ top: 0, behavior: "smooth" });

    // Update URL hash without jumping
    history.replaceState(null, null, `#${sectionId}`);
}

function handleInitialRouting() {
    const hash = window.location.hash.replace("#", "");
    if (hash && ["home", "products", "consultations", "about", "contact"].includes(hash)) {
        switchSection(hash);
    }
}

function toggleMobileMenu() {
    const mainNav = document.getElementById("mainNav");
    mainNav.classList.toggle("mobile-active");
}

// --------------------------------------------------------------------------
// 5. Products Catalog Logic & Nahdi Filtering with Subcategories
// --------------------------------------------------------------------------
function renderProductsCatalog() {
    const grid = document.getElementById("productsCatalogGrid");
    const emptyState = document.getElementById("emptyProductsState");

    if (!grid) return;

    // Filter products
    let filtered = PRODUCTS_DATA.filter(item => {
        // Category Match
        const matchCategory = state.currentCategory === "all" || item.category === state.currentCategory;
        
        // Subcategory Match (real relational match, not keyword guessing)
        let matchSubcategory = true;
        if (state.activeSubcategoryId) {
            matchSubcategory = item.subcategoryId === state.activeSubcategoryId;
        }

        // Search Match (Global or Inline)
        const activeSearch = (state.searchQuery || state.inlineSearchQuery).trim().toLowerCase();
        const matchSearch = !activeSearch || 
            item.nameAr.toLowerCase().includes(activeSearch) || 
            item.nameEn.toLowerCase().includes(activeSearch) ||
            item.categoryName.toLowerCase().includes(activeSearch);

        return matchCategory && matchSubcategory && matchSearch;
    });

    // Sort products
    if (state.sortBy === "price-asc") {
        filtered.sort((a, b) => a.price - b.price);
    } else if (state.sortBy === "price-desc") {
        filtered.sort((a, b) => b.price - a.price);
    } else if (state.sortBy === "name") {
        filtered.sort((a, b) => a.nameAr.localeCompare(b.nameAr, 'ar'));
    }

    // Render HTML
    if (filtered.length === 0) {
        grid.innerHTML = "";
        emptyState.style.display = "block";
    } else {
        emptyState.style.display = "none";
        grid.innerHTML = filtered.map(product => {
            const badgeClass = product.badgeType === "discount" ? "badge-discount" : "badge-official";
            const oldPriceHtml = product.oldPrice ? `<span class="old-price">${product.oldPrice.toFixed(2)} ج.م</span>` : "";
            const badgeHtml = product.badge ? `<span class="product-badge-tag ${badgeClass}">${product.badge}</span>` : "";
            const imageHtml = product.imageUrl
                ? `<img src="${product.imageUrl}" alt="${product.nameAr}" loading="lazy" style="width:100%;height:100%;object-fit:cover;border-radius:inherit;">`
                : `<i class="fa-solid ${product.icon}"></i>`;

            return `
                <div class="product-card" data-id="${product.id}">
                    ${badgeHtml}
                    <div class="product-img-wrap">
                        ${imageHtml}
                    </div>
                    <span class="product-cat-name">${product.categoryName}</span>
                    <h4 class="product-name">${product.nameAr}</h4>
                    <span class="product-en-name">${product.nameEn}</span>
                    
                    <div class="product-price-row">
                        <span class="current-price">${product.price.toFixed(2)} ج.م</span>
                        ${oldPriceHtml}
                    </div>

                    <button class="btn-add-order" onclick="addToCart('${product.id}')">
                        <i class="fa-solid fa-cart-plus"></i>
                        <span>إضافة للطلب</span>
                    </button>
                </div>
            `;
        }).join("");
    }
}

function filterProductsByCategory(category) {
    state.currentCategory = category;
    clearSubcategoryFilter(false);

    // Update pill buttons
    const pills = document.querySelectorAll(".cat-pill");
    pills.forEach(pill => {
        if (pill.getAttribute("data-category") === category) {
            pill.classList.add("active");
        } else {
            pill.classList.remove("active");
        }
    });

    // Tap-to-open the subcategory dropdown on touch devices. The panel's
    // visibility is controlled via opacity/visibility/pointer-events (a
    // fade transition), NOT display — so those are the properties that
    // must be toggled inline to override the :hover-only CSS rule, which
    // never fires on a touch device.
    const clickedWrapper = document.querySelector(`.cat-item-wrapper .cat-pill[data-category="${category}"]`)?.closest(".cat-item-wrapper");
    const clickedMenu = clickedWrapper?.querySelector(".subcat-dropdown-menu");
    const isCurrentlyOpen = clickedMenu && clickedMenu.style.visibility === "visible";

    document.querySelectorAll(".cat-item-wrapper .subcat-dropdown-menu").forEach(menu => {
        const shouldOpen = menu === clickedMenu && !isCurrentlyOpen;
        menu.style.opacity = shouldOpen ? "1" : "0";
        menu.style.visibility = shouldOpen ? "visible" : "hidden";
        menu.style.pointerEvents = shouldOpen ? "auto" : "none";
        menu.style.transform = shouldOpen ? "translateY(0)" : "translateY(10px)";

        // Keep the wrapper's own z-index in sync with its dropdown's
        // visibility, so the open one always paints above sibling
        // category pills instead of losing a z-index tie by DOM order.
        const wrapper = menu.closest(".cat-item-wrapper");
        if (wrapper) wrapper.classList.toggle("dropdown-open", shouldOpen);
    });

    renderProductsCatalog();
}

function filterBySubcategoryId(parentCategory, subcategoryId, subcategoryTitle) {
    state.currentCategory = parentCategory;
    state.activeSubcategory = subcategoryTitle;
    state.activeSubcategoryId = subcategoryId;

    // Update category pill active state
    const pills = document.querySelectorAll(".cat-pill");
    pills.forEach(pill => {
        if (pill.getAttribute("data-category") === parentCategory) {
            pill.classList.add("active");
        } else {
            pill.classList.remove("active");
        }
    });

    // Update Active Subcategory Indicator Bar
    const bar = document.getElementById("activeSubcatBar");
    const titleEl = document.getElementById("activeSubcatTitle");
    if (bar && titleEl) {
        titleEl.textContent = subcategoryTitle;
        bar.style.display = "flex";
    }

    renderProductsCatalog();

    // Close any open subcategory panel now that a choice was made
    document.querySelectorAll(".cat-item-wrapper .subcat-dropdown-menu").forEach(menu => {
        menu.style.opacity = "0";
        menu.style.visibility = "hidden";
        menu.style.pointerEvents = "none";
        menu.style.transform = "translateY(10px)";
        menu.closest(".cat-item-wrapper")?.classList.remove("dropdown-open");
    });

    showToast(`تمت التصفية حسب: ${subcategoryTitle}`, "success");
}

function clearSubcategoryFilter(shouldReRender = true) {
    state.activeSubcategory = null;
    state.activeSubcategoryId = null;

    const bar = document.getElementById("activeSubcatBar");
    if (bar) {
        bar.style.display = "none";
    }

    if (shouldReRender) {
        renderProductsCatalog();
    }
}

function filterBySpecificCategory(category) {
    switchSection("products");
    filterProductsByCategory(category);
}

function handleCategoryFilter(category) {
    state.currentCategory = category;
    if (category !== "all") {
        switchSection("products");
        filterProductsByCategory(category);
    }
}

function handleInlineSearch(val) {
    state.inlineSearchQuery = val;
    renderProductsCatalog();
}

function handleProductSort(sortBy) {
    state.sortBy = sortBy;
    renderProductsCatalog();
}

// --------------------------------------------------------------------------
// 6. Nahdi-Style Smart Search Header Listeners
// --------------------------------------------------------------------------
function setupGlobalSearchListeners() {
    const searchInput = document.getElementById("globalSearchInput");
    const dropdown = document.getElementById("searchResultsDropdown");
    const dropdownList = document.getElementById("searchDropdownList");
    const dropdownCount = document.getElementById("dropdownResultsCount");
    const btnClear = document.getElementById("btnClearSearch");

    if (!searchInput) return;

    searchInput.addEventListener("input", (e) => {
        const query = e.target.value.trim().toLowerCase();
        state.searchQuery = query;

        if (query.length > 0) {
            btnClear.style.display = "block";
            
            // Search in data
            const matches = PRODUCTS_DATA.filter(p => 
                p.nameAr.toLowerCase().includes(query) || 
                p.nameEn.toLowerCase().includes(query) || 
                p.categoryName.toLowerCase().includes(query)
            );

            dropdownCount.textContent = `${matches.length} منتجات`;

            if (matches.length > 0) {
                dropdownList.innerHTML = matches.slice(0, 6).map(p => `
                    <div class="search-dropdown-item" onclick="selectSearchItem('${p.id}')">
                        <div class="search-item-info">
                            <div class="search-item-icon"><i class="fa-solid ${p.icon}"></i></div>
                            <div>
                                <div class="search-item-title">${p.nameAr}</div>
                                <div class="search-item-category">${p.categoryName} - ${p.nameEn}</div>
                            </div>
                        </div>
                        <div class="search-item-price">${p.price.toFixed(2)} ج.م</div>
                    </div>
                `).join("");
                dropdown.classList.add("active");
            } else {
                dropdownList.innerHTML = `
                    <div style="padding: 1.5rem; text-align: center; color: #64748B;">
                        لا توجد نتائج مطابقة لـ "<strong>${e.target.value}</strong>"<br>
                        <button class="btn btn-link" style="margin-top: 0.5rem;" onclick="openPrescriptionModal()">طلب توفير هذا الدواء</button>
                    </div>
                `;
                dropdown.classList.add("active");
            }
        } else {
            btnClear.style.display = "none";
            dropdown.classList.remove("active");
        }
    });

    // Close dropdown on outside click
    document.addEventListener("click", (e) => {
        if (!e.target.closest(".search-bar-container")) {
            dropdown.classList.remove("active");
        }
    });
}

function clearSearch() {
    const searchInput = document.getElementById("globalSearchInput");
    const btnClear = document.getElementById("btnClearSearch");
    const dropdown = document.getElementById("searchResultsDropdown");
    
    if (searchInput) searchInput.value = "";
    if (btnClear) btnClear.style.display = "none";
    if (dropdown) dropdown.classList.remove("active");
    
    state.searchQuery = "";
    renderProductsCatalog();
}

function executeSearch() {
    const searchInput = document.getElementById("globalSearchInput");
    const dropdown = document.getElementById("searchResultsDropdown");
    if (dropdown) dropdown.classList.remove("active");
    
    switchSection("products");
    renderProductsCatalog();
}

function selectSearchItem(productId) {
    const dropdown = document.getElementById("searchResultsDropdown");
    if (dropdown) dropdown.classList.remove("active");

    switchSection("products");
    const product = PRODUCTS_DATA.find(p => p.id === productId);
    if (product) {
        addToCart(productId);
        showToast(`تمت إضافة "${product.nameAr}" لسلة الطلبات`, "success");
    }
}

// --------------------------------------------------------------------------
// 7. Cart & Orders Drawer Logic
// --------------------------------------------------------------------------
function addToCart(productId) {
    const product = PRODUCTS_DATA.find(p => p.id === productId);
    if (!product) return;

    const existingIndex = state.cart.findIndex(item => item.id === productId);
    if (existingIndex > -1) {
        state.cart[existingIndex].quantity += 1;
    } else {
        state.cart.push({
            id: product.id,
            nameAr: product.nameAr,
            price: product.price,
            icon: product.icon,
            quantity: 1
        });
    }

    updateCartUI();
    showToast(`تمت إضافة ${product.nameAr} إلى قائمة طلباتك`, "success");
}

function updateCartUI() {
    const badge = document.getElementById("cartCountBadge");
    const cartList = document.getElementById("cartDrawerItems");
    const cartTotalPrice = document.getElementById("cartTotalPrice");

    const totalCount = state.cart.reduce((sum, item) => sum + item.quantity, 0);
    const totalPrice = state.cart.reduce((sum, item) => sum + (item.price * item.quantity), 0);

    if (badge) badge.textContent = totalCount;
    if (cartTotalPrice) cartTotalPrice.textContent = `${totalPrice.toFixed(2)} ج.م`;

    if (!cartList) return;

    if (state.cart.length === 0) {
        cartList.innerHTML = `
            <div style="text-align: center; padding: 3rem 1rem; color: #94A3B8;">
                <i class="fa-solid fa-basket-shopping" style="font-size: 3rem; margin-bottom: 1rem; color: #CBD5E1;"></i>
                <p>قائمة الطلبات فارغة حالياً</p>
                <button class="btn btn-primary" style="margin-top: 1rem;" onclick="toggleCartDrawer(); switchSection('products');">تصفح الأدوية والتجميل</button>
            </div>
        `;
    } else {
        cartList.innerHTML = state.cart.map(item => `
            <div class="cart-item">
                <div class="cart-item-details">
                    <h5>${item.nameAr}</h5>
                    <div class="cart-item-price">${(item.price * item.quantity).toFixed(2)} ج.م (${item.price.toFixed(2)} ج.م للواحد)</div>
                </div>
                <div class="cart-item-actions">
                    <button class="btn-qty" onclick="updateItemQuantity('${item.id}', -1)">-</button>
                    <span style="font-weight: 700; min-width: 20px; text-align: center;">${item.quantity}</span>
                    <button class="btn-qty" onclick="updateItemQuantity('${item.id}', 1)">+</button>
                    <button class="btn-qty" style="color: #EF4444;" onclick="removeItemFromCart('${item.id}')" title="حذف"><i class="fa-solid fa-trash"></i></button>
                </div>
            </div>
        `).join("");
    }
}

function updateItemQuantity(productId, delta) {
    const item = state.cart.find(i => i.id === productId);
    if (!item) return;

    item.quantity += delta;
    if (item.quantity <= 0) {
        state.cart = state.cart.filter(i => i.id !== productId);
    }

    updateCartUI();
}

function removeItemFromCart(productId) {
    state.cart = state.cart.filter(i => i.id !== productId);
    updateCartUI();
}

function toggleCartDrawer() {
    const drawer = document.getElementById("cartDrawer");
    if (drawer) {
        drawer.classList.toggle("active");
    }
}

function checkoutFromCart() {
    toggleCartDrawer();
    switchSection("products");

    // Populate order textarea with cart items
    const medicineInput = document.getElementById("orderMedicineNames");
    if (medicineInput && state.cart.length > 0) {
        const orderSummary = state.cart.map(item => `${item.nameAr} (العدد: ${item.quantity})`).join(" + ");
        medicineInput.value = orderSummary;
    }

    // Scroll smoothly to the booking form
    const bookingForm = document.getElementById("bookingFormContainer");
    if (bookingForm) {
        bookingForm.scrollIntoView({ behavior: "smooth" });
    }
}

// --------------------------------------------------------------------------
// 8. Medicine Booking & Delivery Toggle Logic
// --------------------------------------------------------------------------
function toggleDeliveryFields(isDelivery) {
    const branchGroup = document.getElementById("branchSelectorGroup");
    const addressWrapper = document.getElementById("deliveryAddressWrapper");

    if (isDelivery) {
        if (branchGroup) branchGroup.style.display = "none";
        if (addressWrapper) addressWrapper.style.display = "block";
    } else {
        if (branchGroup) branchGroup.style.display = "block";
        if (addressWrapper) addressWrapper.style.display = "none";
    }
}

function handleFileSelect(event) {
    const file = event.target.files[0];
    const label = document.getElementById("rxFileLabel");
    if (file && label) {
        label.innerHTML = `<strong>تم اختيار الملف:</strong> ${file.name} (${(file.size / 1024).toFixed(1)} KB)`;
        label.style.color = "#0D8A64";
    }
}

async function handleMedicineOrderSubmit(event) {
    event.preventDefault();

    // Get basic customer information
    const medicines = document.getElementById("orderMedicineNames").value.trim();
    const name = document.getElementById("orderPatientName").value.trim();
    const phone = document.getElementById("orderPhone").value.trim();

    const deliveryMethodElement = document.querySelector(
        'input[name="deliveryMethod"]:checked'
    );

    if (!deliveryMethodElement) {
        showToast("يرجى اختيار طريقة استلام الطلب", "error");
        return;
    }

    const deliveryMethod = deliveryMethodElement.value;

    // Egyptian phone validation
    const phoneRegex = /^01[0125][0-9]{8}$/;

    if (!phoneRegex.test(phone)) {
        showToast(
            "يرجى إدخال رقم هاتف مصري صحيح يبدأ بـ 010 أو 011 أو 012 أو 015 ومكون من 11 رقماً",
            "error"
        );
        return;
    }

    // Generate order tracking number
    const randomNum = Math.floor(10000 + Math.random() * 90000);
    const trackingCode = `AWD-EGY-${randomNum}`;

    // Prepare delivery information
    let deliveryText = "";
    let addressText = "";
    let selectedBranchId = null;

    if (deliveryMethod === "delivery") {

        const gov = document.getElementById("orderGov").value;
        const city = document.getElementById("orderCity").value.trim();
        const street = document.getElementById("orderStreet").value.trim();
        const building = document.getElementById("orderBuilding").value.trim();
        const apartment = document.getElementById("orderApartment").value.trim();
        const landmark = document.getElementById("orderLandmark").value.trim();
        const gpsLink = document.getElementById("mainGpsCoordinates").value.trim();

        deliveryText = "توصيل للمنزل";

        addressText =
            `المحافظة: ${gov}\n` +
            `المنطقة: ${city}\n` +
            `الشارع: ${street}\n` +
            `رقم العمارة: ${building}\n` +
            `الشقة والدور: ${apartment || "غير محدد"}\n` +
            `علامة مميزة: ${landmark || "لا يوجد"}\n` +
            `GPS: ${gpsLink || "غير محدد"}`;

    } else {

        const branchSelectEl = document.getElementById("orderBranch");
        selectedBranchId = branchSelectEl.value; // UUID الفرع من جدول branches
        const branchName = branchSelectEl.options[branchSelectEl.selectedIndex].text;

        deliveryText = `استلام من الصيدلية - ${branchName}`;

        addressText = branchName;
    }

    // Additional notes
    let notes = document.getElementById("orderNotes").value.trim();

    // Selected prescription file (if any)
    const rxFileInput = document.getElementById("rxFileInput");
    const selectedRxFile = rxFileInput?.files?.[0] || null;

    // Disable submit button while sending
    const submitButton = event.target.querySelector('button[type="submit"]');

    if (submitButton) {
        submitButton.disabled = true;
        submitButton.innerHTML = `
            <i class="fa-solid fa-spinner fa-spin"></i>
            جاري إرسال الطلب...
        `;
    }

    try {

        // Upload prescription image (if provided) before creating the order
        let prescriptionUrl = null;

        if (selectedRxFile) {
            prescriptionUrl = await uploadPrescriptionFile(selectedRxFile);

            if (!prescriptionUrl) {
                showToast(
                    "تعذر رفع صورة الروشتة، سيتم إرسال الطلب بدونها. يمكنك إرسالها لاحقاً عبر الواتساب.",
                    "error"
                );
            } else {
                notes = notes
                    ? `${notes}\nروشتة مرفقة: ${prescriptionUrl}`
                    : `روشتة مرفقة: ${prescriptionUrl}`;
            }
        }

        // Send order to Supabase
        const { data, error } = await supabaseClient
            .from("orders")
            .insert({
                customer_name: name,
                phone: phone,
                medications: medicines,
                delivery_method: deliveryText,
                address: addressText,
                notes: notes,
                prescription_url: prescriptionUrl,
                status: "new",
                tracking_code: trackingCode,
                branch_id: selectedBranchId,
                order_type: deliveryMethod === "delivery" ? "delivery" : "pickup"
            });
            
        // Check for database error
        if (error) {
            console.error("Supabase order error:", error);

            showToast(
                "حدث خطأ أثناء إرسال الطلب. يرجى المحاولة مرة أخرى.",
                "error"
            );

            return;
        }

        console.log("Order successfully created:", data);

        // Show success information
        document.getElementById("successTrackingNumber").textContent =
            trackingCode;

        document.getElementById("successPatientName").textContent =
            name;

        document.getElementById("successPhone").textContent =
            phone;

        document.getElementById("successDeliveryType").textContent =
            deliveryText;

        const successModal =
            document.getElementById("orderSuccessModal");

        if (successModal) {
            successModal.classList.add("active");
        }

        // Reset form
        event.target.reset();

        // Reset cart
        state.cart = [];
        updateCartUI();

        // Reset prescription label
        const rxLabel =
            document.getElementById("rxFileLabel");

        if (rxLabel) {
            rxLabel.textContent =
                "اضغط هنا لرفع صورة الروشتة أو اسحب الملف";
        }

        // Reset GPS
        const mainLocStatus =
            document.getElementById("mainLocationStatus");

        if (mainLocStatus) {
            mainLocStatus.textContent = "";
            mainLocStatus.className =
                "location-status-badge";
        }

        const mainGps =
            document.getElementById("mainGpsCoordinates");

        if (mainGps) {
            mainGps.value = "";
        }

        toggleDeliveryFields(false);

    } catch (error) {

        console.error("Unexpected order error:", error);

        showToast(
            "حدث خطأ غير متوقع أثناء إرسال الطلب.",
            "error"
        );

    } finally {

        // Re-enable submit button
        if (submitButton) {
            submitButton.disabled = false;

            submitButton.innerHTML = `
                <i class="fa-solid fa-paper-plane"></i>
                تأكيد وإرسال طلب الأدوية
            `;
        }
    }
}

// --------------------------------------------------------------------------
// 9. Quick Prescription Modal Handlers & GPS Geolocation
// --------------------------------------------------------------------------
function openPrescriptionModal() {
    const modal = document.getElementById("prescriptionModal");
    if (modal) modal.classList.add("active");
}

function closePrescriptionModal() {
    const modal = document.getElementById("prescriptionModal");
    if (modal) modal.classList.remove("active");
}

function handleModalFileSelect(event) {
    const file = event.target.files[0];
    const label = document.getElementById("modalRxFileLabel");
    if (file && label) {
        label.innerHTML = `<strong>تم اختيار الملف:</strong> ${file.name} (${(file.size / 1024).toFixed(1)} KB)`;
        label.style.color = "#0D8A64";
    }
}

function toggleModalDeliveryLocation(isDelivery) {
    const locationBox = document.getElementById("modalDeliveryLocationBox");
    const branchBox = document.getElementById("modalBranchSelectBox");

    if (isDelivery) {
        if (locationBox) locationBox.style.display = "flex";
        if (branchBox) branchBox.style.display = "none";
    } else {
        if (locationBox) locationBox.style.display = "none";
        if (branchBox) branchBox.style.display = "flex";
    }
}

function detectUserLocation(context = 'modal') {
    const statusEl = document.getElementById(context === 'modal' ? 'modalLocationStatus' : 'mainLocationStatus');
    const gpsInput = document.getElementById(context === 'modal' ? 'modalGpsCoordinates' : 'mainGpsCoordinates');
    const addressInput = document.getElementById(context === 'modal' ? 'modalAddressDetails' : 'orderCity');

    if (!navigator.geolocation) {
        if (statusEl) {
            statusEl.className = "location-status-badge error";
            statusEl.innerHTML = '<i class="fa-solid fa-triangle-exclamation"></i> المتصفح لا يدعم تحديد الموقع';
        }
        showToast("المتصفح لا يدعم خدمة تحديد الموقع التلقائي", "error");
        return;
    }

    if (statusEl) {
        statusEl.className = "location-status-badge loading";
        statusEl.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> جاري التقاط إحداثيات موقعك بدقة...';
    }

    navigator.geolocation.getCurrentPosition(
        (position) => {
            const lat = position.coords.latitude.toFixed(6);
            const lng = position.coords.longitude.toFixed(6);
            const accuracy = Math.round(position.coords.accuracy);
            const mapsUrl = `https://maps.google.com/?q=${lat},${lng}`;

            if (gpsInput) gpsInput.value = mapsUrl;

            if (statusEl) {
                statusEl.className = "location-status-badge success";
                statusEl.innerHTML = `<i class="fa-solid fa-circle-check"></i> تم تحديد موقعك بدقة (دقة: ${accuracy}م) <a href="${mapsUrl}" target="_blank" style="text-decoration: underline; color: #15803D; margin-right: 4px;">عرض</a>`;
            }

            if (addressInput && !addressInput.value) {
                addressInput.value = `موقع محدد عبر GPS (خط عرض: ${lat}، خط طول: ${lng})`;
            }

            showToast("تم التقاط موقعك الجغرافي بدقة وتثبيته في الطلب! 📍", "success");
        },
        (error) => {
            let errorMsg = "تعذر الحصول على الموقع";
            if (error.code === error.PERMISSION_DENIED) {
                errorMsg = "تم رفض الإذن بالوصول للموقع. يرجى كتابة العنوان يدوياً.";
            } else if (error.code === error.POSITION_UNAVAILABLE) {
                errorMsg = "معلومات الموقع غير متوفرة حالياً.";
            } else if (error.code === error.TIMEOUT) {
                errorMsg = "انتهت مهلة طلب الموقع.";
            }

            if (statusEl) {
                statusEl.className = "location-status-badge error";
                statusEl.innerHTML = `<i class="fa-solid fa-circle-exclamation"></i> ${errorMsg}`;
            }

            showToast(errorMsg, "error");
        },
        {
            enableHighAccuracy: true,
            timeout: 10000,
            maximumAge: 0
        }
    );
}

async function handleQuickRxModalSubmit(event) {
    event.preventDefault();

    // Customer information
    const name = document.getElementById("modalRxName").value.trim();
    const phone = document.getElementById("modalRxPhone").value.trim();

    // Medicines / prescription text
    const medicines = document.getElementById("modalRxText").value.trim();

    // Delivery method
    const methodElement = document.querySelector(
        'input[name="modalDeliveryMethod"]:checked'
    );

    if (!methodElement) {
        showToast("يرجى اختيار طريقة الاستلام", "error");
        return;
    }

    const method = methodElement.value;

    // Validate Egyptian phone
    const phoneRegex = /^01[0125][0-9]{8}$/;

    if (!phoneRegex.test(phone)) {
        showToast(
            "يرجى إدخال رقم هاتف مصري صحيح مكون من 11 رقماً",
            "error"
        );
        return;
    }

    // Generate tracking number
    const randomNum = Math.floor(10000 + Math.random() * 90000);
    const trackingCode = `AWD-RX-${randomNum}`;

    // Delivery information
    let deliveryDescription = "";
    let address = "";
    let selectedBranchId = null;

    if (method === "delivery") {

        address =
            document.getElementById("modalAddressDetails")?.value.trim() || "";

        const gpsLink =
            document.getElementById("modalGpsCoordinates")?.value.trim() || "";

        deliveryDescription = "توصيل للمنزل";

        if (gpsLink) {
            address = address
                ? `${address}\nGPS: ${gpsLink}`
                : `GPS: ${gpsLink}`;
        }

    } else {

        const modalBranchEl = document.getElementById("modalBranchSelect");
        selectedBranchId = modalBranchEl?.value || null;
        const branchName = modalBranchEl?.options[modalBranchEl.selectedIndex]?.text || "";

        deliveryDescription = `استلام من الفرع - ${branchName}`;
        address = branchName;
    }

    // Selected prescription file
    const fileInput =
        document.getElementById("modalRxFileInput");

    const selectedFile =
        fileInput?.files?.[0] || null;

    // Disable submit button
    const submitButton =
        event.target.querySelector('button[type="submit"]');

    if (submitButton) {
        submitButton.disabled = true;

        submitButton.innerHTML = `
            <i class="fa-solid fa-spinner fa-spin"></i>
            جاري إرسال الطلب...
        `;
    }

    try {

        // Upload prescription image (if provided) before creating the order
        let prescriptionUrl = null;
        let modalNotes = "";

        if (selectedFile) {
            prescriptionUrl = await uploadPrescriptionFile(selectedFile);

            if (!prescriptionUrl) {
                showToast(
                    "تعذر رفع صورة الروشتة، سيتم إرسال الطلب بدونها. يمكنك إرسالها لاحقاً عبر الواتساب.",
                    "error"
                );
                modalNotes = `تم اختيار روشتة (فشل الرفع): ${selectedFile.name}`;
            } else {
                modalNotes = `روشتة مرفقة: ${prescriptionUrl}`;
            }
        }

        // Send order to Supabase
        const { error } = await supabaseClient
            .from("orders")
            .insert({
                customer_name: name,
                phone: phone,
                medications: medicines,
                delivery_method: deliveryDescription,
                address: address,
                notes: modalNotes,
                prescription_url: prescriptionUrl,
                status: "new",
                tracking_code: trackingCode,
                branch_id: selectedBranchId,
                order_type: method === "delivery" ? "delivery" : "pickup"
            });

        // Database error
        if (error) {

            console.error("Supabase order error:", error);

            showToast(
                "حدث خطأ أثناء إرسال الطلب. يرجى المحاولة مرة أخرى.",
                "error"
            );

            return;
        }

        // SUCCESS
        console.log(
            "Order successfully created:",
            trackingCode
        );

        // Close prescription modal
        closePrescriptionModal();

        // Fill success modal
        document.getElementById(
            "successTrackingNumber"
        ).textContent = trackingCode;

        document.getElementById(
            "successPatientName"
        ).textContent = name;

        document.getElementById(
            "successPhone"
        ).textContent = phone;

        document.getElementById(
            "successDeliveryType"
        ).textContent = deliveryDescription;

        // Show success modal
        const successModal =
            document.getElementById("orderSuccessModal");

        if (successModal) {
            successModal.classList.add("active");
        }

        // Reset form
        event.target.reset();

        // Reset upload label
        const fileLabel =
            document.getElementById("modalRxFileLabel");

        if (fileLabel) {
            fileLabel.textContent =
                "اضغط هنا لرفع صورة الروشتة أو اسحب الملف";

            fileLabel.style.color = "";
        }

        // Reset GPS
        const locationStatus =
            document.getElementById("modalLocationStatus");

        if (locationStatus) {
            locationStatus.textContent = "";
            locationStatus.className =
                "location-status-badge";
        }

        const gpsInput =
            document.getElementById("modalGpsCoordinates");

        if (gpsInput) {
            gpsInput.value = "";
        }

        toggleModalDeliveryLocation(true);

    } catch (error) {

        console.error(
            "Unexpected order error:",
            error
        );

        showToast(
            "حدث خطأ غير متوقع أثناء إرسال الطلب.",
            "error"
        );

    } finally {

        if (submitButton) {

            submitButton.disabled = false;

            submitButton.innerHTML = `
                <i class="fa-solid fa-paper-plane"></i>
                إرسال الطلب فوراً
            `;
        }
    }
}

function closeSuccessModal() {
    const successModal = document.getElementById("orderSuccessModal");
    if (successModal) successModal.classList.remove("active");
}

// --------------------------------------------------------------------------
// 10. Medical Consultations & Clinic Booking Logic
// --------------------------------------------------------------------------
const DOCTORS_DATA = [
    {
        name: "أ.د. شريف عبد الرحمن",
        specialty: "باطنة وسكر وغدد صماء",
        branch: "فرع طناح - المنصورة - الدقهلية",
        fee: 250,
        slots: ["السبت 06:00 م", "الإثنين 07:30 م", "الأربعاء 05:00 م"]
    },
    {
        name: "د. مي مجدي",
        specialty: "أمراض جلدية وتجميل وليزر",
        branch: "فرع كفر طناح - المنصورة - الدقهلية",
        fee: 300,
        slots: ["الأحد 04:00 م", "الثلاثاء 06:30 م", "الخميس 05:00 م"]
    },
    {
        name: "د. حسام الدين فاروق",
        specialty: "طب الأطفال وحديثي الولادة",
        branch: "فرع طناح - المنصورة - الدقهلية",
        fee: 220,
        slots: ["السبت 02:00 م", "الإثنين 03:30 م", "الأربعاء 02:00 م"]
    },
    {
        name: "د. ندى الشريف",
        specialty: "تغذية علاجية وسمنة ونحافة",
        branch: "فرع كفر طناح - المنصورة - الدقهلية",
        fee: 200,
        slots: ["الإثنين 05:00 م", "الخميس 07:00 م", "الجمعة 04:00 م"]
    },
    {
        name: "د. طارق مراد",
        specialty: "جراحة العظام والمفاصل",
        branch: "فرع طناح - المنصورة - الدقهلية",
        fee: 280,
        slots: ["السبت 05:00 م", "الثلاثاء 07:00 م"]
    }
];

function switchConsultationMode(mode) {
    const clinicView = document.getElementById("clinicBookingView");
    const remoteView = document.getElementById("remoteBookingView");
    const tabBtnClinic = document.getElementById("tabBtnClinic");
    const tabBtnRemote = document.getElementById("tabBtnRemote");

    if (mode === "clinic") {
        if (clinicView) clinicView.style.display = "block";
        if (remoteView) remoteView.style.display = "none";
        if (tabBtnClinic) tabBtnClinic.classList.add("active");
        if (tabBtnRemote) tabBtnRemote.classList.remove("active");
    } else {
        if (clinicView) clinicView.style.display = "none";
        if (remoteView) remoteView.style.display = "block";
        if (tabBtnClinic) tabBtnClinic.classList.remove("active");
        if (tabBtnRemote) tabBtnRemote.classList.add("active");
    }
}

function selectDoctorForBooking(docName, specialty, branch, slots) {
    // Switch to clinic view if not already
    switchConsultationMode("clinic");

    // Prefer the canonical branch name from DOCTORS_DATA (the branch param
    // passed from the doctor card can be a shortened label like "فرع كفر طناح").
    const docObj = DOCTORS_DATA.find(d => d.name === docName);
    const branchName = docObj ? docObj.branch : branch;

    const branchSelect = document.getElementById("clinicBranchInput");
    if (branchSelect) branchSelect.value = branchName;

    populateDoctorOptionsForBranch(branchName, docName);

    // Scroll to form smoothly
    const formCard = document.getElementById("clinicBookingFormCard");
    if (formCard) {
        formCard.scrollIntoView({ behavior: "smooth" });
    }

    showToast(`تم اختيار ${docName} - يرجى تحديد وقت الكشف المناسب وتأكيد الحجز`, "info");
}

function populateClinicBranchOptions() {
    const branchSelect = document.getElementById("clinicBranchInput");
    if (!branchSelect) return;

    // Flatten all branches from every city in BRANCHES_DATA
    const allBranches = Object.values(BRANCHES_DATA).flat();

    branchSelect.innerHTML = allBranches.map(b => `
        <option value="${b.name}">${b.name}</option>
    `).join("");
}

// Fills the doctor dropdown with only the doctors who work at the given
// branch, and auto-selects one (preferring `preferredDocName` if it's
// actually available there), then renders that doctor's time slots.
function populateDoctorOptionsForBranch(branchName, preferredDocName) {
    const docSelect = document.getElementById("clinicDocSelect");
    if (!docSelect) return;

    const doctorsInBranch = DOCTORS_DATA.filter(d => d.branch === branchName);

    if (doctorsInBranch.length === 0) {
        docSelect.innerHTML = `<option value="">لا يوجد أطباء متاحون في هذا الفرع حالياً</option>`;
        renderInteractiveTimeSlots([]);
        return;
    }

    docSelect.innerHTML = doctorsInBranch.map(d => `
        <option value="${d.name}">${d.name} (${d.specialty})</option>
    `).join("");

    const docToSelect = doctorsInBranch.find(d => d.name === preferredDocName) || doctorsInBranch[0];
    docSelect.value = docToSelect.name;
    renderInteractiveTimeSlots(docToSelect.slots);
}

// Called when the user manually picks a different branch: narrows the
// doctor list down to that branch's doctors.
function onBranchSelectChange(branchName) {
    populateDoctorOptionsForBranch(branchName);
}

function onDoctorSelectChange(docName) {
    const docObj = DOCTORS_DATA.find(d => d.name === docName);
    const branchSelect = document.getElementById("clinicBranchInput");

    if (docObj) {
        if (branchSelect) branchSelect.value = docObj.branch;
        populateDoctorOptionsForBranch(docObj.branch, docName);
    }
}

function renderInteractiveTimeSlots(slots) {
    const container = document.getElementById("interactiveTimeSlotsContainer");
    const inputHidden = document.getElementById("selectedTimeSlotInput");
    if (!container) return;

    if (!slots || slots.length === 0) {
        container.innerHTML = `<p class="text-muted">لا توجد مواعيد متاحة حالياً لهذا الطبيب.</p>`;
        if (inputHidden) inputHidden.value = "";
        return;
    }

    container.innerHTML = slots.map((slot, index) => {
        const isFirst = index === 0 ? "selected" : "";
        return `
            <button type="button" class="time-slot-btn ${isFirst}" onclick="selectTimeSlot('${slot}', this)">
                <i class="fa-solid fa-calendar-day"></i>
                <span>${slot}</span>
            </button>
        `;
    }).join("");

    // Set first slot as default value
    if (inputHidden) {
        inputHidden.value = slots[0];
    }
}

function selectTimeSlot(slotText, btnElement) {
    const allSlotBtns = document.querySelectorAll(".time-slot-btn");
    allSlotBtns.forEach(btn => btn.classList.remove("selected"));

    if (btnElement) {
        btnElement.classList.add("selected");
    }

    const inputHidden = document.getElementById("selectedTimeSlotInput");
    if (inputHidden) {
        inputHidden.value = slotText;
    }
}

function handleClinicAppointmentSubmit(event) {
    event.preventDefault();

    const doctor = document.getElementById("clinicDocSelect").value;
    const branch = document.getElementById("clinicBranchInput").value;
    const slot = document.getElementById("selectedTimeSlotInput").value;
    const patientName = document.getElementById("clinicPatientName").value;
    const patientPhone = document.getElementById("clinicPatientPhone").value;

    const phoneRegex = /^01[0125][0-9]{8}$/;
    if (!phoneRegex.test(patientPhone)) {
        showToast("يرجى إدخال رقم هاتف محمول مصري صحيح (11 رقماً يبدأ بـ 010 أو 011 أو 012 أو 015)", "error");
        return;
    }

    if (!slot) {
        showToast("يرجى اختيار الموعد المتاح المناسب لك", "error");
        return;
    }

    const ticketCode = "CLN-EGY-" + Math.floor(1000 + Math.random() * 9000);

    // Populate modal ticket
    document.getElementById("ticketNumber").textContent = ticketCode;
    document.getElementById("ticketDoctorName").textContent = doctor;
    document.getElementById("ticketBranch").textContent = branch;
    document.getElementById("ticketTimeSlot").textContent = slot;
    document.getElementById("ticketPatientName").textContent = patientName;
    document.getElementById("ticketPhone").textContent = patientPhone;

    // Show modal
    const ticketModal = document.getElementById("clinicTicketModal");
    if (ticketModal) {
        ticketModal.classList.add("active");
    }

    event.target.reset();
    onDoctorSelectChange(doctor);
}

function closeClinicTicketModal() {
    const ticketModal = document.getElementById("clinicTicketModal");
    if (ticketModal) {
        ticketModal.classList.remove("active");
    }
}

function selectConsultationType(typeName) {
    switchConsultationMode("remote");
    const select = document.getElementById("consType");
    if (select) {
        select.value = typeName;
    }
    const formCard = document.querySelector(".consultation-form-card");
    if (formCard) {
        formCard.scrollIntoView({ behavior: "smooth" });
    }
}

function handleConsultationSubmit(event) {
    event.preventDefault();

    const name = document.getElementById("consName").value;
    const phone = document.getElementById("consPhone").value;
    const type = document.getElementById("consType").value;
    const time = document.getElementById("consTime").value;

    const phoneRegex = /^01[0125][0-9]{8}$/;
    if (!phoneRegex.test(phone)) {
        showToast("يرجى إدخال رقم هاتف مصري صحيح (11 رقماً)", "error");
        return;
    }

    showToast(`تم حجز استشارتك الطبية بنجاح يا ${name}! سيتواصل معك الصيدلي الاستشاري في ${time}.`, "success");
    event.target.reset();
}

// --------------------------------------------------------------------------
// 11. Branch Locator & Contact Us Logic
// --------------------------------------------------------------------------
function showBranchCity(cityKey) {
    const branchesContainer = document.getElementById("branchesList");
    const buttons = document.querySelectorAll(".branch-tab-btn");

    buttons.forEach(btn => {
        if (btn.getAttribute("onclick").includes(cityKey)) {
            btn.classList.add("active");
        } else {
            btn.classList.remove("active");
        }
    });

    const branches = BRANCHES_DATA[cityKey] || [];
    if (branchesContainer) {
        branchesContainer.innerHTML = branches.map(b => `
            <div class="branch-item-card">
                <h4><i class="fa-solid fa-hospital" style="color: var(--primary); margin-left: 0.4rem;"></i> ${b.name}</h4>
                <p><i class="fa-solid fa-location-dot" style="color: var(--text-muted); margin-left: 0.4rem;"></i> <strong>العنوان:</strong> ${b.address}</p>
                <p><i class="fa-solid fa-phone" style="color: var(--text-muted); margin-left: 0.4rem;"></i> <strong>التليفون:</strong> ${b.phone} | <a href="tel:${b.phone}" style="color: var(--primary); font-weight: bold;">اتصال مباشر</a></p>
                <p><i class="fa-solid fa-clock" style="color: var(--text-muted); margin-left: 0.4rem;"></i> <strong>المواعيد:</strong> ${b.hours}</p>
                <p><i class="fa-solid fa-user-doctor" style="color: var(--text-muted); margin-left: 0.4rem;"></i> <strong>مدير الفرع:</strong> ${b.manager}</p>
            </div>
        `).join("");
    }
}

function handleContactSubmit(event) {
    event.preventDefault();

    const name = document.getElementById("contactName").value;
    const phone = document.getElementById("contactPhone").value;

    const phoneRegex = /^01[0125][0-9]{8}$/;
    if (!phoneRegex.test(phone)) {
        showToast("يرجى إدخال رقم هاتف مصري صحيح (11 رقماً)", "error");
        return;
    }

    showToast(`شكراً لتواصلك يا ${name}. تم استلام رسالتك وسيتم الرد عليك في أقرب وقت.`, "success");
    event.target.reset();
}

// --------------------------------------------------------------------------
// 12. Toast Notification Helper
// --------------------------------------------------------------------------
function showToast(message, type = "success") {
    const container = document.getElementById("toastContainer");
    if (!container) return;

    const toast = document.createElement("div");
    toast.className = `toast toast-${type}`;
    const icon = type === "success" ? "fa-circle-check" : "fa-circle-exclamation";
    toast.innerHTML = `<i class="fa-solid ${icon}"></i> <span>${message}</span>`;

    container.appendChild(toast);

    setTimeout(() => {
        toast.style.opacity = "0";
        toast.style.transform = "translateX(100%)";
        toast.style.transition = "all 0.3s ease";
        setTimeout(() => toast.remove(), 300);
    }, 4500);
}
