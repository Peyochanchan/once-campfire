Rails.application.config.permissions_policy do |f|
  f.camera      :self
  f.microphone  :self
  f.fullscreen  :self
  f.gyroscope   :none
  f.usb         :none
  f.payment     :none
  f.magnetometer :none
end
