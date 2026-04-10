module Message::Attachment
  extend ActiveSupport::Concern

  THUMBNAIL_MAX_WIDTH = 1200
  THUMBNAIL_MAX_HEIGHT = 800

  MAX_ATTACHMENT_SIZE = 100.megabytes

  BLOCKED_CONTENT_TYPES = %w[
    application/x-msdownload application/x-executable application/x-msdos-program
    application/x-sh application/x-csh
  ].freeze

  included do
    has_one_attached :attachment do |attachable|
      attachable.variant :thumb, resize_to_limit: [ THUMBNAIL_MAX_WIDTH, THUMBNAIL_MAX_HEIGHT ]
    end

    validate :attachment_size_and_type

    private
      def attachment_size_and_type
        return unless attachment.attached?

        if attachment.blob.byte_size > MAX_ATTACHMENT_SIZE
          errors.add(:attachment, "is too large (max #{MAX_ATTACHMENT_SIZE / 1.megabyte}MB)")
        end

        if BLOCKED_CONTENT_TYPES.include?(attachment.blob.content_type)
          errors.add(:attachment, "type is not allowed")
        end
      end
  end

  module ClassMethods
    def create_with_attachment!(attributes)
      create!(attributes).tap(&:process_attachment)
    end
  end

  def attachment?
    attachment.attached?
  end

  def process_attachment
    ensure_attachment_analyzed
    process_attachment_thumbnail
  end

  private
    def ensure_attachment_analyzed
      attachment&.analyze
    end

    def process_attachment_thumbnail
      case
      when attachment.video?
        attachment.preview(format: :webp).processed
      when attachment.representable?
        attachment.representation(:thumb).processed
      end
    end
end
