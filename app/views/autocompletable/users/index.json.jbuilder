json.array! @global_mentions + @page.records.to_a do |item|
  if item.is_a?(String)
    json.value       "@#{item}"
    json.name        "@#{item}"
    json.type        "global"
    json.avatar_url  asset_path(item == "here" ? "notification-bell-mentions.svg" : "everyone.svg")
  else
    json.partial! "autocompletable/users/user", user: item
  end
end
