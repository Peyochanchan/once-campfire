module AccountsHelper
  def account_logo_tag(style: nil)
    tag.figure image_tag(fresh_account_logo_path, alt: "Account logo", size: 300), class: "account-logo avatar #{style}"
  end

  def button_to_toggle_setting(label, setting)
    button_to account_path(account: { settings: { setting => !Current.account.settings.send("#{setting}?") } }),
      method: :put,
      role: "checkbox", aria: { checked: true, labelledby: "#{setting}_account_setting" }, tabindex: 0,
      class: "btn" do
        tag.span(label, id: "#{setting}_account_setting")
    end
  end
end
