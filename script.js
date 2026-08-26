
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
 * ==========================================================================
 * صيدليات العوضي (Elawadi Pharmacies) - Main JavaScript
 * Pure Vanilla JS (ES6+) - No Frameworks
 * ==========================================================================
 */

// --------------------------------------------------------------------------
// 1. Data Store: Products Catalog & Branches
// --------------------------------------------------------------------------
const PRODUCTS_DATA = [
    {
        id: 1,
        nameAr: "بنادول إكسترا 24 قرص",
        nameEn: "Panadol Extra 24 Tablets",
        category: "medicines",
        categoryName: "الأدوية والعلاجات",
        price: 45.00,
        oldPrice: 50.00,
        badge: "الأكثر طلباً",
        badgeType: "official",
        icon: "fa-pills",
        inStock: true
    },
    {
        id: 2,
        nameAr: "كونكور 5 مجم 30 قرص",
        nameEn: "Concor 5mg 30 Tablets",
        category: "medicines",
        categoryName: "الأدوية والعلاجات",
        price: 58.50,
        oldPrice: null,
        badge: "أدوية الضغط والقلب",
        badgeType: "official",
        icon: "fa-heart-pulse",
        inStock: true
    },
    {
        id: 3,
        nameAr: "أوجمنتين 1 جم 14 قرص",
        nameEn: "Augmentin 1g 14 Tablets",
        category: "medicines",
        categoryName: "الأدوية والعلاجات",
        price: 110.00,
        oldPrice: null,
        badge: "مضاد حيوي معتمد",
        badgeType: "official",
        icon: "fa-capsules",
        inStock: true
    },
    {
        id: 4,
        nameAr: "سيرافيه غسول مرطب للبشرة 236 مل",
        nameEn: "CeraVe Hydrating Cleanser 236ml",
        category: "skincare",
        categoryName: "العناية بالبشرة",
        price: 360.00,
        oldPrice: 420.00,
        badge: "خصم 15%",
        badgeType: "discount",
        icon: "fa-pump-soap",
        inStock: true
    },
    {
        id: 5,
        nameAr: "لاروش بوزيه أنثيليوس واقي شمس SPF50+",
        nameEn: "La Roche-Posay Anthelios Invisible Fluid",
        category: "skincare",
        categoryName: "العناية بالبشرة",
        price: 680.00,
        oldPrice: 750.00,
        badge: "أصلي 100%",
        badgeType: "official",
        icon: "fa-sun",
        inStock: true
    },
    {
        id: 6,
        nameAr: "بيوديرما ماء ميسيلار سينسيبيو 500 مل",
        nameEn: "Bioderma Sensibio H2O Micellar Water 500ml",
        category: "skincare",
        categoryName: "العناية بالبشرة",
        price: 490.00,
        oldPrice: 560.00,
        badge: "عرض خاص",
        badgeType: "discount",
        icon: "fa-wand-magic-sparkles",
        inStock: true
    },
    {
        id: 7,
        nameAr: "فيشي ديركوس شامبو ضد القشرة 200 مل",
        nameEn: "Vichy Dercos Anti-Dandruff Shampoo 200ml",
        category: "haircare",
        categoryName: "العناية بالشعر",
        price: 420.00,
        oldPrice: null,
        badge: "علاج طبي",
        badgeType: "official",
        icon: "fa-spa",
        inStock: true
    },
    {
        id: 8,
        nameAr: "سيروم دكتور ميركل لنمو الشعر 118 مل",
        nameEn: "Dr. Miracle's Daily Anti-Breakage Serum",
        category: "haircare",
        categoryName: "العناية بالشعر",
        price: 310.00,
        oldPrice: 360.00,
        badge: "الأكثر مبيعاً",
        badgeType: "discount",
        icon: "fa-feather",
        inStock: true
    },
    {
        id: 9,
        nameAr: "سنتروم مكمل غذائي مع لوتين 30 قرص",
        nameEn: "Centrum with Lutein Multivitamin 30 Tabs",
        category: "vitamins",
        categoryName: "الفيتامينات والمكملات",
        price: 195.00,
        oldPrice: 220.00,
        badge: "دعم المناعة",
        badgeType: "official",
        icon: "fa-shield-virus",
        inStock: true
    },
    {
        id: 10,
        nameAr: "أوميجا 3 بلس 30 كبسولة",
        nameEn: "Omega-3 Plus 30 Capsules",
        category: "vitamins",
        categoryName: "الفيتامينات والمكملات",
        price: 85.00,
        oldPrice: null,
        badge: "صحة القلب",
        badgeType: "official",
        icon: "fa-apple-whole",
        inStock: true
    },
    {
        id: 11,
        nameAr: "حفاضات بامبرز بريميوم كير مقاس 3 (60 حفاضة)",
        nameEn: "Pampers Premium Care Size 3 (60 Pcs)",
        category: "baby",
        categoryName: "الأم والطفل",
        price: 340.00,
        oldPrice: 380.00,
        badge: "عناية فائقة",
        badgeType: "discount",
        icon: "fa-baby",
        inStock: true
    },
    {
        id: 12,
        nameAr: "حليب أبتاميل 1 للرضع 400 جم",
        nameEn: "Aptamil 1 Infant Formula 400g",
        category: "baby",
        categoryName: "الأم والطفل",
        price: 260.00,
        oldPrice: null,
        badge: "غذاء الرضع",
        badgeType: "official",
        icon: "fa-baby-carriage",
        inStock: true
    },
    {
        id: 13,
        nameAr: "جهاز قياس السكر أكوا تشيك إنستانت + 50 شريط",
        nameEn: "Accu-Chek Instant Blood Glucose Meter",
        category: "devices",
        categoryName: "الأجهزة والمعدات الطبية",
        price: 750.00,
        oldPrice: 890.00,
        badge: "ضمان عامين",
        badgeType: "discount",
        icon: "fa-gauge-high",
        inStock: true
    },
    {
        id: 14,
        nameAr: "جهاز قياس ضغط الدم ديجيتال بيورير BM28",
        nameEn: "Beurer BM28 Digital Blood Pressure Monitor",
        category: "devices",
        categoryName: "الأجهزة والمعدات الطبية",
        price: 1350.00,
        oldPrice: 1550.00,
        badge: "ألماني أصلي",
        badgeType: "official",
        icon: "fa-heart-circle-bolt",
        inStock: true
    },
    {
        id: 15,
        nameAr: "كريم بيبانثين المرطب للجلد 30 جم",
        nameEn: "Bepanthen Moisturizing Cream 30g",
        category: "skincare",
        categoryName: "العناية بالبشرة",
        price: 90.00,
        oldPrice: null,
        badge: "ترطيب عميق",
        badgeType: "official",
        icon: "fa-pump-medical",
        inStock: true
    },
    {
        id: 16,
        nameAr: "أقراص استحلاب ستربسلس بالعسل والليمون",
        nameEn: "Strepsils Honey & Lemon 24 Lozenges",
        category: "medicines",
        categoryName: "الأدوية والعلاجات",
        price: 125.00,
        oldPrice: null,
        badge: "تسكين الحلق",
        badgeType: "official",
        icon: "fa-head-side-cough",
        inStock: true
    }
];

const BRANCHES_DATA = {
    cairo: [
        {
            name: "فرع مصر الجديدة (الرئيسي)",
            address: "ميدان تريومف - شارع النزهة، مصر الجديدة، القاهرة",
            phone: "02-24180001",
            hours: "24 ساعة يومياً (خدمة التوصيل متاحة)",
            manager: "د. أحمد سامي"
        },
        {
            name: "فرع التجمع الخامس",
            address: "شارع التسعين الشمالي - أمام مول كايرو فيستيفال، القاهرة الجديدة",
            phone: "02-28100002",
            hours: "24 ساعة يومياً (خدمة التوصيل متاحة)",
            manager: "د. هدى مراد"
        },
        {
            name: "فرع المعادي",
            address: "شارع النصر - بجوار ميدان الجزائر، المعادي، القاهرة",
            phone: "02-25190003",
            hours: "24 ساعة يومياً (خدمة التوصيل متاحة)",
            manager: "د. كريم يوسف"
        }
    ],
    giza: [
        {
            name: "فرع الدقي",
            address: "شارع مصدق - متفرع من محيي الدين أبو العز، الدقي، الجيزة",
            phone: "02-37610004",
            hours: "24 ساعة يومياً (خدمة التوصيل متاحة)",
            manager: "د. عمر طارق"
        },
        {
            name: "فرع الشيخ زايد",
            address: "وصلة دهشور - كمبوند بيفرلي هيلز، الشيخ زايد، الجيزة",
            phone: "02-38500005",
            hours: "24 ساعة يومياً (خدمة التوصيل متاحة)",
            manager: "د. سارة عادل"
        }
    ],
    alex: [
        {
            name: "فرع سموحة",
            address: "شارع فوزي معاذ - بجوار نادي سموحة، الإسكندرية",
            phone: "03-4290006",
            hours: "24 ساعة يومياً (خدمة التوصيل متاحة)",
            manager: "د. ماجد فتحي"
        },
        {
            name: "فرع لوران",
            address: "طريق الحرية (شارع أبو قير) - لوران، الإسكندرية",
            phone: "03-5840007",
            hours: "24 ساعة يومياً (خدمة التوصيل متاحة)",
            manager: "د. نورهان شوقي"
        }
    ],
    delta: [
        {
            name: "فرع المنصورة",
            address: "شارع المشاية السفلية - أمام حديقة شجرة الدر، المنصورة، الدقهلية",
            phone: "050-2310008",
            hours: "24 ساعة يومياً (خدمة التوصيل متاحة)",
            manager: "د. حسام العوضي"
        }
    ]
};

// --------------------------------------------------------------------------
// 2. Application State
// --------------------------------------------------------------------------
let state = {
    currentCategory: "all",
    activeSubcategory: null,
    activeSubcategoryKeyword: "",
    searchQuery: "",
    inlineSearchQuery: "",
    sortBy: "featured",
    cart: []
};

// --------------------------------------------------------------------------
// 3. App Initialization
// --------------------------------------------------------------------------
document.addEventListener("DOMContentLoaded", () => {
    // Initial products render
    renderProductsCatalog();

    // Initial branches render
    showBranchCity("cairo");

    // Initial doctor slots render
    onDoctorSelectChange("أ.د. شريف عبد الرحمن");

    // Check URL hash for routing
    handleInitialRouting();

    // Setup global search live listener
    setupGlobalSearchListeners();
});

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
        
        // Subcategory Keyword Match
        let matchSubcategory = true;
        if (state.activeSubcategoryKeyword) {
            const kw = state.activeSubcategoryKeyword.toLowerCase();
            matchSubcategory = item.nameAr.toLowerCase().includes(kw) || 
                               item.nameEn.toLowerCase().includes(kw) || 
                               item.badge.toLowerCase().includes(kw) ||
                               item.categoryName.toLowerCase().includes(kw);
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
            
            return `
                <div class="product-card" data-id="${product.id}">
                    <span class="product-badge-tag ${badgeClass}">${product.badge}</span>
                    <div class="product-img-wrap">
                        <i class="fa-solid ${product.icon}"></i>
                    </div>
                    <span class="product-cat-name">${product.categoryName}</span>
                    <h4 class="product-name">${product.nameAr}</h4>
                    <span class="product-en-name">${product.nameEn}</span>
                    
                    <div class="product-price-row">
                        <span class="current-price">${product.price.toFixed(2)} ج.م</span>
                        ${oldPriceHtml}
                    </div>

                    <button class="btn-add-order" onclick="addToCart(${product.id})">
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

    renderProductsCatalog();
}

function filterBySubcategory(parentCategory, subcategoryTitle, keyword) {
    state.currentCategory = parentCategory;
    state.activeSubcategory = subcategoryTitle;
    state.activeSubcategoryKeyword = keyword;

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

    showToast(`تمت التصفية حسب: ${subcategoryTitle}`, "success");
}

function clearSubcategoryFilter(shouldReRender = true) {
    state.activeSubcategory = null;
    state.activeSubcategoryKeyword = "";

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
                    <div class="search-dropdown-item" onclick="selectSearchItem(${p.id})">
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
                    <button class="btn-qty" onclick="updateItemQuantity(${item.id}, -1)">-</button>
                    <span style="font-weight: 700; min-width: 20px; text-align: center;">${item.quantity}</span>
                    <button class="btn-qty" onclick="updateItemQuantity(${item.id}, 1)">+</button>
                    <button class="btn-qty" style="color: #EF4444;" onclick="removeItemFromCart(${item.id})" title="حذف"><i class="fa-solid fa-trash"></i></button>
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

        const branch = document.getElementById("orderBranch").value;

        deliveryText = `استلام من الصيدلية - ${branch}`;

        addressText = branch;
    }

    // Additional notes
    const notes = document.getElementById("orderNotes").value.trim();

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
                status: "new",
                tracking_code: trackingCode
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

function handleQuickRxModalSubmit(event) {
    event.preventDefault();

    const name = document.getElementById("modalRxName").value;
    const phone = document.getElementById("modalRxPhone").value;
    const method = document.querySelector('input[name="modalDeliveryMethod"]:checked').value;
    const address = document.getElementById("modalAddressDetails") ? document.getElementById("modalAddressDetails").value : "";
    const gpsLink = document.getElementById("modalGpsCoordinates") ? document.getElementById("modalGpsCoordinates").value : "";
    const branch = document.getElementById("modalBranchSelect") ? document.getElementById("modalBranchSelect").value : "";

    const phoneRegex = /^01[0125][0-9]{8}$/;
    if (!phoneRegex.test(phone)) {
        showToast("يرجى إدخال رقم هاتف محمول مصري صحيح (11 رقماً)", "error");
        return;
    }

    closePrescriptionModal();

    // Show confirmation modal
    const randomNum = Math.floor(10000 + Math.random() * 90000);
    const trackingCode = `AWD-RX-${randomNum}`;

    let deliveryDescription = "";
    if (method === "delivery") {
        deliveryDescription = `توصيل منزلي سريع 24/7 ${address ? `(${address})` : ''} ${gpsLink ? '[مرفق موقع GPS دقيق]' : ''}`;
    } else {
        deliveryDescription = `استلام من (${branch || 'الفرع المحدد'})`;
    }

    document.getElementById("successTrackingNumber").textContent = trackingCode;
    document.getElementById("successPatientName").textContent = name;
    document.getElementById("successPhone").textContent = phone;
    document.getElementById("successDeliveryType").textContent = deliveryDescription;

    const successModal = document.getElementById("orderSuccessModal");
    if (successModal) successModal.classList.add("active");

    event.target.reset();
    const modalFileLabel = document.getElementById("modalRxFileLabel");
    if (modalFileLabel) modalFileLabel.textContent = "اضغط هنا لرفع صورة الروشتة أو اسحب الملف";
    
    const modalLocStatus = document.getElementById("modalLocationStatus");
    if (modalLocStatus) {
        modalLocStatus.textContent = "";
        modalLocStatus.className = "location-status-badge";
    }
    const modalGps = document.getElementById("modalGpsCoordinates");
    if (modalGps) modalGps.value = "";
    toggleModalDeliveryLocation(true);
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
        branch: "فرع مصر الجديدة (القاهرة)",
        fee: 250,
        slots: ["السبت 06:00 م", "الإثنين 07:30 م", "الأربعاء 05:00 م"]
    },
    {
        name: "د. مي مجدي",
        specialty: "أمراض جلدية وتجميل وليزر",
        branch: "فرع التجمع الخامس (القاهرة)",
        fee: 300,
        slots: ["الأحد 04:00 م", "الثلاثاء 06:30 م", "الخميس 05:00 م"]
    },
    {
        name: "د. حسام الدين فاروق",
        specialty: "طب الأطفال وحديثي الولادة",
        branch: "فرع المعادي (القاهرة)",
        fee: 220,
        slots: ["السبت 02:00 م", "الإثنين 03:30 م", "الأربعاء 02:00 م"]
    },
    {
        name: "د. ندى الشريف",
        specialty: "تغذية علاجية وسمنة ونحافة",
        branch: "فرع الدقي (الجيزة)",
        fee: 200,
        slots: ["الإثنين 05:00 م", "الخميس 07:00 م", "الجمعة 04:00 م"]
    },
    {
        name: "د. طارق مراد",
        specialty: "جراحة العظام والمفاصل",
        branch: "فرع الشيخ زايد (الجيزة)",
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

    const docSelect = document.getElementById("clinicDocSelect");
    const branchInput = document.getElementById("clinicBranchInput");

    if (docSelect) docSelect.value = docName;
    if (branchInput) branchInput.value = branch;

    renderInteractiveTimeSlots(slots);

    // Scroll to form smoothly
    const formCard = document.getElementById("clinicBookingFormCard");
    if (formCard) {
        formCard.scrollIntoView({ behavior: "smooth" });
    }

    showToast(`تم اختيار ${docName} - يرجى تحديد وقت الكشف المناسب وتأكيد الحجز`, "info");
}

function onDoctorSelectChange(docName) {
    const docObj = DOCTORS_DATA.find(d => d.name === docName);
    const branchInput = document.getElementById("clinicBranchInput");

    if (docObj) {
        if (branchInput) branchInput.value = docObj.branch;
        renderInteractiveTimeSlots(docObj.slots);
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
