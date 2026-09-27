# 09 — Frontend Auth Hardening (F11)

## Summary of Finding (F11)
In both `Admin File - Elawadi Clinics Dashboard/js/auth.js` and `Admin File - Pharmacy Dashboard/js/auth.js`, if a user signed in via Supabase Auth but did not have a corresponding profile record in `clinic_profiles` or `profiles`, the code fell back to dynamically creating or granting an in-memory **Admin / Clinic Admin profile**.

This created a **privilege escalation security risk**: an unauthorized user or any user missing a database profile was granted full admin privileges in the frontend UI.

---

## ⚠️ Pre-Deployment Operational Warning (Critical)

> [!CAUTION]
> **Do NOT deploy this frontend change before verifying that an active Admin record exists in the database!**
> 
> Because auto-creation and fallback admin privileges are removed, any user attempting to log in without an active DB record in `profiles` or `clinic_profiles` (`is_active = true`) will be signed out and denied access.
> 
> Execute these queries in Supabase SQL Editor to verify your account exists before deployment:
> ```sql
> -- 1. Verify active Admin profile for Pharmacy Dashboard:
> SELECT id, full_name, role, is_active FROM public.profiles WHERE role = 'admin' AND is_active = true;
> 
> -- 2. Verify active Clinic Admin profile for Clinics Dashboard:
> SELECT id, full_name, clinic_role, is_active FROM public.clinic_profiles WHERE clinic_role = 'clinic_admin' AND is_active = true;
> ```

---

## Technical Solution

1. **Add `noProfileError` Key to `i18n.js`**:
   - Added translation key `noProfileError` to both Arabic (`ar`) and English (`en`) dictionaries in `Admin File - Pharmacy Dashboard/js/i18n.js` and `Admin File - Elawadi Clinics Dashboard/js/i18n.js`.
   - Prevents `i18n.t("noProfileError")` from returning the raw key string `"noProfileError"`.

2. **Remove Admin Fallbacks in `auth.js`**:
   - In `loadUserProfile()`, if the profile query returns `error` or `null`, `this.profile` is set to `null`.
   - Removed automatic creation of `clinic_admin` profiles in the database from the client.
   - Removed in-memory fallback objects that assign `admin` / `clinic_admin` roles.

3. **Enforce Profile Requirement in `init()`**:
   - If `!this.profile` after `loadUserProfile()`, call `this.signOut()`, notify the user with an alert using `i18n.t("noProfileError")`, and redirect to `login.html`.

---

## Code Changes Applied

### 1. `i18n.js` Updates (Pharmacy & Clinics)

```js
// Added to TRANSLATIONS.ar:
noProfileError: "حسابك غير مسجل في النظام. يرجى التواصل مع الإدارة."

// Added to TRANSLATIONS.en:
noProfileError: "Your account is not registered in the system. Please contact the administrator."
```

### 2. Elawadi Clinics Dashboard (`Admin File - Elawadi Clinics Dashboard/js/auth.js`)

```js
// In init():
this.user = session.user;
await this.loadUserProfile();

if (!this.profile) {
    console.warn("No clinic profile found for user:", this.user.id);
    await this.signOut();
    alert(typeof i18n !== "undefined" && i18n.t("noProfileError") ? i18n.t("noProfileError") : "حسابك غير مسجل في النظام. يرجى التواصل مع المسؤول.");
    window.location.href = "login.html";
    return false;
}
```

### 3. Pharmacy Dashboard (`Admin File - Pharmacy Dashboard/js/auth.js`)

```js
// In init():
this.user = session.user;
await this.loadUserProfile();

if (!this.profile) {
    console.warn("No profile found for user:", this.user.id);
    await this.signOut();
    alert(typeof i18n !== "undefined" && i18n.t("noProfileError") ? i18n.t("noProfileError") : "حسابك غير مسجل في النظام. يرجى التواصل مع المسؤول.");
    window.location.href = "login.html";
    return false;
}
```

---

## Verification
- Clean login test with valid user + existing profile: Logins successfully with assigned role (`admin`, `staff`, or `doctor`).
- Login attempt with valid auth user BUT no profile in database: Bounced to `login.html` displaying the translated Arabic message: `"حسابك غير مسجل في النظام. يرجى التواصل مع الإدارة."`.
- Inactive user profile (`is_active = false`): Automatically signed out and redirected to `login.html`.
