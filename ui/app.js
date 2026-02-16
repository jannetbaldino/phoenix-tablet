(() => {
  const root = document.getElementById("root");
  const timeEl = document.getElementById("time");
  const phoneNum = document.getElementById("phoneNum");

  const homeView = document.getElementById("homeView");
  const appView = document.getElementById("appView");

  const appTitle = document.getElementById("appTitle");
  const appBody = document.getElementById("appBody");

  const backBtn = document.getElementById("backBtn");
  const closeBtn = document.getElementById("closeBtn");

  // ========= Permission Catalog (UI Checkboxes) =========
  const PERM_CATALOG = [
    {
      group: "Business",
      items: [
        { label: "Manage business", code: "business.manage" },
        { label: "Manage points (POS/clock/trays/storage/craft)", code: "points.manage" },
      ],
    },
    {
      group: "Employees",
      items: [{ label: "Manage employees (hire/update/fire)", code: "employees.manage" }],
    },
    {
      group: "Roles",
      items: [{ label: "Manage roles", code: "roles.manage" }],
    },
    {
      group: "POS",
      items: [
        { label: "Use POS", code: "pos.use" },
        { label: "Manage POS/items", code: "pos.manage" },
      ],
    },
    {
      group: "Storage",
      items: [
        { label: "Open storage", code: "storage.open" },
        { label: "Manage storage", code: "storage.manage" },
        { label: "Open tray (public stash)", code: "tray.open" },
      ],
    },
    {
      group: "Crafting",
      items: [
        { label: "Use crafting", code: "craft.use" },
        { label: "Manage crafting", code: "craft.manage" },
      ],
    },
    {
      group: "Bank",
      items: [
        { label: "View business bank", code: "bank.view" },
        { label: "Manage business bank", code: "bank.manage" },
      ],
    },
  ];

  const PERM_LOOKUP = (() => {
    const out = {};
    for (const g of PERM_CATALOG) {
      for (const it of g.items) out[it.code] = it.label;
    }
    return out;
  })();

  let state = {
    bootstrap: null,
    isAdmin: false,

    businesses: [],
    selectedBusinessId: null,
    selectedBusiness: null, // full payload from server

    // Role editor state
    roleEditor: {
      id: null,
      name: "",
      grade: 0,
      perms: new Set(),
    },
  };

  root.classList.add("hidden");

  function setTime() {
    const d = new Date();
    timeEl.textContent =
      String(d.getHours()).padStart(2, "0") +
      ":" +
      String(d.getMinutes()).padStart(2, "0");
  }

  function showHome() {
    homeView.classList.remove("hidden");
    appView.classList.add("hidden");
  }

  function showApp(app) {
    homeView.classList.add("hidden");
    appView.classList.remove("hidden");

    if (app === "business") {
      renderBusinessApp();
      return;
    }

    appTitle.textContent = "App";
    appBody.innerHTML = `<div class="muted">Coming soon.</div>`;
  }

  // NUI helper
  async function nui(action, data = {}) {
    const res = await fetch(`https://${GetParentResourceName()}/${action}`, {
      method: "POST",
      headers: { "Content-Type": "application/json; charset=UTF-8" },
      body: JSON.stringify(data),
    });
    return res.json();
  }

  async function loadBusinesses() {
    const r = await nui("biz_listBusinesses", {});
    if (!r || !r.ok) return [];
    return r.data || [];
  }

  async function loadBusiness(businessId) {
    const r = await nui("biz_getBusiness", { businessId });
    if (!r || !r.ok) return null;
    return r.data || null;
  }

  function escapeHtml(s) {
    return String(s || "")
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#039;");
  }

  function permsToText(perms) {
    if (!Array.isArray(perms) || perms.length === 0) return "None";
    return perms.join(", ");
  }

  function prettyPerm(code) {
    return PERM_LOOKUP[code] || code;
  }

  function setRoleEditorFromRole(role) {
    const id = role && role.id ? Number(role.id) : null;
    const name = role && role.name ? String(role.name) : "";
    const grade = role && role.grade != null ? Number(role.grade) : 0;
    const permsArr = Array.isArray(role && role.perms) ? role.perms : [];

    state.roleEditor.id = id;
    state.roleEditor.name = name;
    state.roleEditor.grade = Number.isFinite(grade) ? grade : 0;
    state.roleEditor.perms = new Set(permsArr.filter(Boolean));
  }

  function clearRoleEditor() {
    state.roleEditor.id = null;
    state.roleEditor.name = "";
    state.roleEditor.grade = 0;
    state.roleEditor.perms = new Set();
  }

  function getSelectedRole(payload, roleId) {
    const roles = payload && payload.roles ? payload.roles : [];
    for (const r of roles) {
      if (Number(r.id) === Number(roleId)) return r;
    }
    return null;
  }

  async function renderBusinessApp() {
    appTitle.textContent = "Business Management";

    // If we don't have the list yet, load it
    if (!state.businesses || state.businesses.length === 0) {
      state.businesses = await loadBusinesses();
    }

    const bizOptions = state.businesses
      .map(
        (b) =>
          `<option value="${b.id}" ${
            Number(state.selectedBusinessId) === Number(b.id) ? "selected" : ""
          }>${escapeHtml(b.name)}</option>`
      )
      .join("");

    const adminTools = state.isAdmin
      ? `
        <div class="section">
          <div class="sectionTitle">Admin</div>

          <div style="display:flex; gap:10px; flex-wrap:wrap;">
            <button class="backBtn" id="bizRefreshBtn">Refresh</button>
            <button class="backBtn" id="bizPlacementBtn">Open Placement Tool</button>
          </div>

          <div style="height:12px;"></div>

          <div style="display:flex; gap:10px; align-items:center; flex-wrap:wrap;">
            <input id="bizCreateName" class="payInput" style="width:260px; text-align:left;" placeholder="New business name" />
            <button class="backBtn" id="bizCreateBtn">Create Business</button>
          </div>
        </div>
      `
      : `
        <div class="section">
          <div class="sectionTitle">Admin</div>
          <div class="muted">You do not have admin permissions.</div>
          <div style="height:8px;"></div>
          <button class="backBtn" id="bizRefreshBtn">Refresh</button>
        </div>
      `;

    appBody.innerHTML = `
      <div class="section">
        <div class="sectionTitle">Select Business</div>

        <div style="display:flex; gap:10px; align-items:center; flex-wrap:wrap;">
          <select id="bizSelect" class="payInput" style="width:340px; text-align:left;">
            <option value="">-- Select --</option>
            ${bizOptions}
          </select>
          <button class="backBtn" id="bizLoadBtn">Load</button>
        </div>
      </div>

      ${adminTools}

      <div class="section">
        <div class="sectionTitle">Details</div>
        <div id="bizDetails" class="muted">Select a business and click Load.</div>
      </div>
    `;

    // Wire buttons
    document.getElementById("bizRefreshBtn").addEventListener("click", async () => {
      state.businesses = await loadBusinesses();
      state.selectedBusiness = null;
      clearRoleEditor();
      renderBusinessApp();
    });

    const placementBtn = document.getElementById("bizPlacementBtn");
    if (placementBtn) {
      placementBtn.addEventListener("click", async () => {
        await nui("biz_openPlacement", { businessId: state.selectedBusinessId });
      });
    }

    const createBtn = document.getElementById("bizCreateBtn");
    if (createBtn) {
      createBtn.addEventListener("click", async () => {
        const name = document.getElementById("bizCreateName").value.trim();
        if (!name) return;

        const r = await nui("biz_createBusiness", { name });
        if (!r || !r.ok) {
          alert("Create failed: " + (r?.error || "unknown"));
          return;
        }

        state.businesses = await loadBusinesses();
        state.selectedBusinessId = r.data.businessId;
        state.selectedBusiness = await loadBusiness(state.selectedBusinessId);
        clearRoleEditor();
        renderBusinessApp();
      });
    }

    document.getElementById("bizLoadBtn").addEventListener("click", async () => {
      const sel = document.getElementById("bizSelect").value;
      if (!sel) return;
      state.selectedBusinessId = Number(sel);
      state.selectedBusiness = await loadBusiness(state.selectedBusinessId);

      // Default role editor to first role if exists
      clearRoleEditor();
      if (state.selectedBusiness && Array.isArray(state.selectedBusiness.roles) && state.selectedBusiness.roles.length > 0) {
        setRoleEditorFromRole(state.selectedBusiness.roles[0]);
      }

      renderBusinessDetails();
    });

    document.getElementById("bizSelect").addEventListener("change", (e) => {
      state.selectedBusinessId = e.target.value ? Number(e.target.value) : null;
    });

    // If one already selected, auto-load
    if (state.selectedBusinessId && !state.selectedBusiness) {
      state.selectedBusiness = await loadBusiness(state.selectedBusinessId);
      clearRoleEditor();
      if (state.selectedBusiness && Array.isArray(state.selectedBusiness.roles) && state.selectedBusiness.roles.length > 0) {
        setRoleEditorFromRole(state.selectedBusiness.roles[0]);
      }
    }
    if (state.selectedBusiness) renderBusinessDetails();
  }

  function renderPermCheckboxes() {
    const selected = state.roleEditor.perms;

    const blocks = PERM_CATALOG.map((g) => {
      const items = g.items
        .map((it) => {
          const checked = selected.has(it.code) ? "checked" : "";
          const id = `perm_${it.code.replaceAll(".", "_")}`;
          return `
            <label class="permItem" for="${id}">
              <input type="checkbox" id="${id}" data-perm="${escapeHtml(it.code)}" ${checked} />
              <div class="permText">
                <div class="permLabel">${escapeHtml(it.label)}</div>
                <div class="permCode">${escapeHtml(it.code)}</div>
              </div>
            </label>
          `;
        })
        .join("");

      return `
        <div class="permGroup">
          <div class="permGroupTitle">${escapeHtml(g.group)}</div>
          <div class="permGrid">${items}</div>
        </div>
      `;
    }).join("");

    return `<div class="permWrap">${blocks}</div>`;
  }

  function renderBusinessDetails() {
    const el = document.getElementById("bizDetails");
    const payload = state.selectedBusiness;

    if (!payload) {
      el.innerHTML = `<div class="muted">No business loaded.</div>`;
      return;
    }

    const b = payload.business || {};
    const roles = payload.roles || [];

    const rolesHtml = roles
      .map((r) => {
        const isSelected = Number(state.roleEditor.id) === Number(r.id);
        return `
          <button class="roleRow ${isSelected ? "roleRowActive" : ""}" data-roleid="${r.id}">
            <div class="empInfo">
              <div class="empName">${escapeHtml(r.name)}</div>
              <div class="empRole">Grade: ${Number(r.grade ?? 0)} • ${escapeHtml(permsToText(r.perms))}</div>
            </div>
            <div class="roleHint">Edit</div>
          </button>
        `;
      })
      .join("");

    const adminRoleEditor = state.isAdmin
      ? `
        <div style="height:14px;"></div>

        <div class="sectionTitle">Role Editor</div>

        <div style="display:flex; gap:10px; flex-wrap:wrap; align-items:center;">
          <button class="backBtn" id="newRoleBtn">New Role</button>
          <div class="muted">${state.roleEditor.id ? `Editing role #${state.roleEditor.id}` : "Creating new role"}</div>
        </div>

        <div style="height:12px;"></div>

        <div style="display:flex; gap:10px; flex-wrap:wrap;">
          <input id="roleName" class="payInput" style="width:260px; text-align:left;" placeholder="Role name" value="${escapeHtml(state.roleEditor.name)}" />
          <input id="roleGrade" class="payInput" style="width:140px; text-align:left;" placeholder="Grade #" type="number" min="0" value="${Number(state.roleEditor.grade || 0)}" />
        </div>

        <div style="height:12px;"></div>
        <div class="muted" style="margin-bottom:10px;">Permissions</div>

        ${renderPermCheckboxes()}

        <div style="height:12px;"></div>
        <button class="backBtn" id="saveRoleBtn">Save Role</button>
        <button class="backBtn dangerBtn" id="deleteRoleBtn" style="display:${state.roleEditor.id ? 'inline-flex' : 'none'};">Delete Role</button>

        <div style="height:18px;"></div>
        <div class="sectionTitle">Hire / Update Employee</div>
        <div style="display:flex; gap:10px; flex-wrap:wrap;">
          <input id="hireCitizenid" class="payInput" style="width:260px; text-align:left;" placeholder="citizenid" />
          <input id="hireRoleId" class="payInput" style="width:140px; text-align:left;" placeholder="role id" type="number" />
          <input id="hireGrade" class="payInput" style="width:140px; text-align:left;" placeholder="grade" type="number" min="0" />
          <button class="backBtn" id="hireBtn">Hire/Update</button>
        </div>
      `
      : "";

    el.innerHTML = `
      <div class="section">
        <div class="sectionTitle">${escapeHtml(b.name || "Business")}</div>
        <div class="muted">Use the placement tool to add POS, clock-in, trays, storage, and crafting points.</div>
      </div>

      <div class="section">
        <div class="sectionTitle">Roles</div>
        <div class="employeeList">
          ${rolesHtml || `<div class="muted">No roles configured.</div>`}
        </div>
        ${adminRoleEditor}
      </div>
    `;

    // Click-to-edit on roles list
    document.querySelectorAll(".roleRow[data-roleid]").forEach((btn) => {
      btn.addEventListener("click", async () => {
        const roleId = Number(btn.getAttribute("data-roleid"));
        const role = getSelectedRole(state.selectedBusiness, roleId);
        if (!role) return;

        setRoleEditorFromRole(role);
        renderBusinessDetails();
      });
    });

    if (!state.isAdmin) return;

    // New role clears form
    document.getElementById("newRoleBtn").addEventListener("click", () => {
      clearRoleEditor();
      renderBusinessDetails();
    });

    // Wire perms checkbox toggles
    document.querySelectorAll('input[type="checkbox"][data-perm]').forEach((cb) => {
      cb.addEventListener("change", (e) => {
        const perm = e.target.getAttribute("data-perm");
        if (!perm) return;
        if (e.target.checked) state.roleEditor.perms.add(perm);
        else state.roleEditor.perms.delete(perm);
      });
    });

    // Save role (create or update)
    document.getElementById("saveRoleBtn").addEventListener("click", async () => {
      const name = document.getElementById("roleName").value.trim();
      const grade = Number(document.getElementById("roleGrade").value || 0);

      if (!name) {
        alert("Role name is required.");
        return;
      }

      const perms = Array.from(state.roleEditor.perms);

      const role = {
        id: state.roleEditor.id ? Number(state.roleEditor.id) : undefined,
        name,
        grade,
        perms,
      };

      const r = await nui("biz_upsertRole", {
        businessId: state.selectedBusinessId,
        role,
      });

      if (!r || !r.ok) {
        alert("Save role failed: " + (r?.error || "unknown"));
        return;
      }

      state.selectedBusiness = await loadBusiness(state.selectedBusinessId);

      // After save: if we were creating new role, select the closest match by name
      const updatedRoles = (state.selectedBusiness && state.selectedBusiness.roles) || [];
      const match = updatedRoles.find((x) => String(x.name).toLowerCase() === name.toLowerCase());
      if (match) setRoleEditorFromRole(match);
      else clearRoleEditor();

      renderBusinessDetails();
    });

    const deleteBtn = document.getElementById("deleteRoleBtn");
if (deleteBtn) {
  deleteBtn.addEventListener("click", async () => {
    if (!state.roleEditor.id) return;

    const roleId = Number(state.roleEditor.id);
    const role = getSelectedRole(state.selectedBusiness, roleId);
    const name = role ? role.name : `#${roleId}`;

    const ok = confirm(`Delete role "${name}"?\n\nEmployees on this role will be moved to another role.`);
    if (!ok) return;

    const r = await nui("biz_deleteRole", {
      businessId: state.selectedBusinessId,
      roleId
    });

    if (!r || !r.ok) {
      alert("Delete failed: " + (r?.error || "unknown"));
      return;
    }

    // Reload business + select first role
    state.selectedBusiness = await loadBusiness(state.selectedBusinessId);
    clearRoleEditor();

    const updatedRoles = (state.selectedBusiness && state.selectedBusiness.roles) || [];
    if (updatedRoles.length > 0) setRoleEditorFromRole(updatedRoles[0]);

    renderBusinessDetails();
  });
}

    // Hire/update employee (unchanged)
    document.getElementById("hireBtn").addEventListener("click", async () => {
      const citizenid = document.getElementById("hireCitizenid").value.trim();
      const roleId = Number(document.getElementById("hireRoleId").value || 0) || null;
      const grade = Number(document.getElementById("hireGrade").value || 0);

      if (!citizenid) {
        alert("citizenid is required.");
        return;
      }

      const r = await nui("biz_hireEmployee", {
        businessId: state.selectedBusinessId,
        citizenid,
        roleId,
        grade,
      });

      if (!r || !r.ok) {
        alert("Hire failed: " + (r?.error || "unknown"));
        return;
      }

      alert("Employee saved.");
    });
  }

  // App icon clicks
  document.querySelectorAll(".appIcon[data-open]").forEach((btn) => {
    btn.addEventListener("click", () => {
      showApp(btn.getAttribute("data-open"));
    });
  });

  backBtn.addEventListener("click", showHome);

  closeBtn.addEventListener("click", async () => {
    await nui("close_tablet", {});
  });

  window.addEventListener("message", async (event) => {
    const msg = event.data || {};

    if (msg.action === "open") {
      root.classList.remove("hidden");
      showHome();
      setTime();

      state.bootstrap = msg.data || null;
      state.isAdmin = !!(msg.data && msg.data.isAdmin);

      if (state.bootstrap && state.bootstrap.user) {
        phoneNum.textContent = state.bootstrap.user.phone_number || "#----";
      }

      // Prime businesses list for Business app
      state.businesses = await loadBusinesses();
    }

    if (msg.action === "close") {
      root.classList.add("hidden");
      showHome();
    }
  });

  setInterval(setTime, 1000);
})();
