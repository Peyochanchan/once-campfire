import { application } from "./application"

import auto_submit from "./auto_submit_controller"
import autocomplete from "./autocomplete_controller"
import badge_dot from "./badge_dot_controller"
import boost_delete from "./boost_delete_controller"
import call_banner from "./call_banner_controller"
import composer from "./composer_controller"
import copy_to_clipboard from "./copy_to_clipboard_controller"
import drop_target from "./drop_target_controller"
import element_removal from "./element_removal_controller"
import filter from "./filter_controller"
import form from "./form_controller"
import lightbox from "./lightbox_controller"
import local_time from "./local_time_controller"
import maintain_scroll from "./maintain_scroll_controller"
import messages from "./messages_controller"
import notifications from "./notifications_controller"
import otp_input from "./otp_input_controller"
import popup from "./popup_controller"
import presence from "./presence_controller"
import pwa_install from "./pwa_install_controller"
import read_rooms from "./read_rooms_controller"
import refresh_room from "./refresh_room_controller"
import reply from "./reply_controller"
import rich_autocomplete from "./rich_autocomplete_controller"
import rooms_list from "./rooms_list_controller"
import scroll_into_view from "./scroll_into_view_controller"
import search_results from "./search_results_controller"
import sessions from "./sessions_controller"
import soft_keyboard from "./soft_keyboard_controller"
import sorted_list from "./sorted_list_controller"
import sound from "./sound_controller"
import toggle_class from "./toggle_class_controller"
import turbo_frame from "./turbo_frame_controller"
import turbo_streaming from "./turbo_streaming_controller"
import typing_notifications from "./typing_notifications_controller"
import upload_preview from "./upload_preview_controller"
import video_call from "./video_call_controller"
import web_share from "./web_share_controller"

application.register("auto-submit", auto_submit)
application.register("autocomplete", autocomplete)
application.register("badge-dot", badge_dot)
application.register("boost-delete", boost_delete)
application.register("call-banner", call_banner)
application.register("composer", composer)
application.register("copy-to-clipboard", copy_to_clipboard)
application.register("drop-target", drop_target)
application.register("element-removal", element_removal)
application.register("filter", filter)
application.register("form", form)
application.register("lightbox", lightbox)
application.register("local-time", local_time)
application.register("maintain-scroll", maintain_scroll)
application.register("messages", messages)
application.register("notifications", notifications)
application.register("otp-input", otp_input)
application.register("popup", popup)
application.register("presence", presence)
application.register("pwa-install", pwa_install)
application.register("read-rooms", read_rooms)
application.register("refresh-room", refresh_room)
application.register("reply", reply)
application.register("rich-autocomplete", rich_autocomplete)
application.register("rooms-list", rooms_list)
application.register("scroll-into-view", scroll_into_view)
application.register("search-results", search_results)
application.register("sessions", sessions)
application.register("soft-keyboard", soft_keyboard)
application.register("sorted-list", sorted_list)
application.register("sound", sound)
application.register("toggle-class", toggle_class)
application.register("turbo-frame", turbo_frame)
application.register("turbo-streaming", turbo_streaming)
application.register("typing-notifications", typing_notifications)
application.register("upload-preview", upload_preview)
application.register("video-call", video_call)
application.register("web-share", web_share)
