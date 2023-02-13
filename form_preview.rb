class FormPreview < ApplicationRecord
  has_many :form_pages, dependent: :restrict_with_exception, foreign_key: :form_preview_erp_id, primary_key: :erp_id
  has_many :preview_assets, dependent: :destroy

  mount_uploader :archive, SecuredUploader
  has_one_attached :main_file, dependent: :destroy

  validates :erp_id, presence: true, uniqueness: true, allow_blank: false
  validates :archive, presence: true, on: :create
  validate :validate_archive, if: -> { archive.file.present? }

  after_commit :create_assets, if: -> { archive.file.present? }

  private

  def validate_archive
    Zip::File.open_buffer(File.read(archive.file.file)) do |zip_file|
      errors.add(:archive, 'Archive must contain files') unless zip_file.entries.any?(&:file?)
      errors.add(:archive, 'index.html is mandatory') if zip_file.glob('**/index.html').empty?

      zip_file.each do |entry|
        next unless entry.file?

        errors.add(:archive, 'Archive contains empty file') if entry.size.zero?
      end
    end
  end

  def create_assets
    PreviewAssetsCreateJob.perform_later(self)
  end

  def main_file_url
    main_file.url
  rescue URI::InvalidURIError
    nil
  end
end
