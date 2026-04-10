require "zlib"

module Users::AvatarsHelper
  AVATAR_COLORS = %w[
    #AF2E1B #CC6324 #3B4B59 #BFA07A #ED8008 #ED3F1C #BF1B1B #736B1E #D07B53
    #736356 #AD1D1D #BF7C2A #C09C6F #698F9C #7C956B #5D618F #3B3633 #67695E
  ]

  def avatar_background_color(user)
    AVATAR_COLORS[Zlib.crc32(user.to_param) % AVATAR_COLORS.size]
  end

  def avatar_tag(user, show_status: false, **options)
    status_class = show_status ? "avatar--#{user.display_status}" : nil
    link_to user_path(user), title: user.title, class: ["btn avatar", status_class].compact.join(" "), data: { turbo_frame: "_top", user_id: user.id } do
      safe_join [
        image_tag(fresh_user_avatar_path(user), aria: { hidden: "true" }, size: 48, **options),
        (tag.span(class: "avatar__status") if show_status)
      ].compact
    end
  end
end
