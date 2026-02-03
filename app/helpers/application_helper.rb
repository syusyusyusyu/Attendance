module ApplicationHelper
  # サイドバーリンクをレンダリング
  def sidebar_link(name, path, icon, badge = nil)
    active = if path == root_path || (defined?(admin_path) && path == admin_path)
      request.path == path
    else
      request.path == path || request.path.start_with?("#{path}/")
    end

    content_tag(:li) do
      link_to path, class: "sidebar-link #{active ? 'active' : ''}", data: { action: "click->sidebar#close" } do
        concat(sidebar_icon(icon))
        concat(content_tag(:span, name))
        if badge.to_i.positive?
          concat(content_tag(:span, badge, class: "sidebar-link-badge"))
        end
      end
    end
  end

  # サイドバーアイコンをレンダリング
  def sidebar_icon(icon)
    icons = {
      "home" => '<svg class="sidebar-link-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z" stroke-linecap="round" stroke-linejoin="round"/><polyline points="9,22 9,12 15,12 15,22" stroke-linecap="round" stroke-linejoin="round"/></svg>',
      "shield" => '<svg class="sidebar-link-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 3l8 4v6c0 5-3.5 7.5-8 9-4.5-1.5-8-4-8-9V7l8-4z" stroke-linecap="round" stroke-linejoin="round"/></svg>',
      "users" => '<svg class="sidebar-link-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2" stroke-linecap="round" stroke-linejoin="round"/><circle cx="9" cy="7" r="4" stroke-linecap="round" stroke-linejoin="round"/><path d="M23 21v-2a4 4 0 00-3-3.87M16 3.13a4 4 0 010 7.75" stroke-linecap="round" stroke-linejoin="round"/></svg>',
      "key" => '<svg class="sidebar-link-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 2l-2 2m-7.61 7.61a5.5 5.5 0 11-7.778 7.778 5.5 5.5 0 017.777-7.777zm0 0L15.5 7.5m0 0l3 3L22 7l-3-3m-3.5 3.5L19 4" stroke-linecap="round" stroke-linejoin="round"/></svg>',
      "user" => '<svg class="sidebar-link-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2" stroke-linecap="round" stroke-linejoin="round"/><circle cx="12" cy="7" r="4" stroke-linecap="round" stroke-linejoin="round"/></svg>',
      "clock" => '<svg class="sidebar-link-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 3" stroke-linecap="round" stroke-linejoin="round"/></svg>',
      "calendar" => '<svg class="sidebar-link-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>',
      "clipboard" => '<svg class="sidebar-link-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M9 3h6a2 2 0 012 2v1H7V5a2 2 0 012-2z"/><rect x="5" y="6" width="14" height="15" rx="2" ry="2"/></svg>',
      "clipboard-check" => '<svg class="sidebar-link-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M9 3h6a2 2 0 012 2v1H7V5a2 2 0 012-2z"/><rect x="5" y="6" width="14" height="15" rx="2" ry="2"/><path d="M9 14l2 2 4-4" stroke-linecap="round" stroke-linejoin="round"/></svg>',
      "qr" => '<svg class="sidebar-link-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="6" height="6"/><rect x="15" y="3" width="6" height="6"/><rect x="3" y="15" width="6" height="6"/><path d="M15 15h6v6h-6z"/><path d="M11 11h2v2h-2z"/></svg>',
      "list" => '<svg class="sidebar-link-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="8" y1="6" x2="21" y2="6"/><line x1="8" y1="12" x2="21" y2="12"/><line x1="8" y1="18" x2="21" y2="18"/><circle cx="4" cy="6" r="1"/><circle cx="4" cy="12" r="1"/><circle cx="4" cy="18" r="1"/></svg>',
      "class" => '<svg class="sidebar-link-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 6h16" stroke-linecap="round" stroke-linejoin="round"/><path d="M4 10h16" stroke-linecap="round" stroke-linejoin="round"/><path d="M4 14h10" stroke-linecap="round" stroke-linejoin="round"/><path d="M4 18h6" stroke-linecap="round" stroke-linejoin="round"/></svg>',
      "report" => '<svg class="sidebar-link-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 3v18h18" stroke-linecap="round" stroke-linejoin="round"/><path d="M7 14l3-3 3 3 5-6" stroke-linecap="round" stroke-linejoin="round"/></svg>',
      "history" => '<svg class="sidebar-link-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 3v6h6" stroke-linecap="round" stroke-linejoin="round"/><path d="M3.75 9A9 9 0 1012 3" stroke-linecap="round" stroke-linejoin="round"/><path d="M12 7v5l3 3" stroke-linecap="round" stroke-linejoin="round"/></svg>',
      "bell" => '<svg class="sidebar-link-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 8a6 6 0 10-12 0c0 7-3 9-3 9h18s-3-2-3-9" stroke-linecap="round" stroke-linejoin="round"/><path d="M13.73 21a2 2 0 01-3.46 0" stroke-linecap="round" stroke-linejoin="round"/></svg>',
      "help" => '<svg class="sidebar-link-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M9.09 9a3 3 0 015.83 1c0 2-3 3-3 3" stroke-linecap="round" stroke-linejoin="round"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>',
      "document" => '<svg class="sidebar-link-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z" stroke-linecap="round" stroke-linejoin="round"/><polyline points="14,2 14,8 20,8" stroke-linecap="round" stroke-linejoin="round"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/><polyline points="10,9 9,9 8,9" stroke-linecap="round" stroke-linejoin="round"/></svg>',
      "external" => '<svg class="ml-auto h-4 w-4 opacity-50" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 13v6a2 2 0 01-2 2H5a2 2 0 01-2-2V8a2 2 0 012-2h6M15 3h6v6M10 14L21 3" stroke-linecap="round" stroke-linejoin="round"/></svg>'
    }

    (icons[icon] || '<svg class="sidebar-link-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/></svg>').html_safe
  end
end
