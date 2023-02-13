class PreviewAssetsCreator
  INVALID_FILE_NAMES = %w[__MACOSX .DS_Store].freeze

  def initialize(form_preview:)
    @form_preview = form_preview
    @archive = @form_preview.archive
  end

  def create
    destroy_previous_assets
    archive_file = File.read(@archive.file.file)
    @archive.remove!
    create_assets(archive_file)
  end

  private

  def create_assets(archive_file)
    Zip::File.open_buffer(archive_file) do |zipfile|
      main_file = zipfile.glob('**/index.html').first
      redundant_path = main_file.name.delete_suffix('index.html')
      zipfile.each do |entry|
        next if invalid_file?(entry)

        entry == main_file ? create_main_file(entry) : create_asset(entry, redundant_path)
      end
    end
  end

  def create_main_file(entry)
    @form_preview.main_file.attach(io: StringIO.new(entry.get_input_stream.read), filename: entry.name.rpartition('/').last)
  end

  def create_asset(entry, redundant_path)
    entry_path = entry.name.delete_prefix(redundant_path)
    asset = PreviewAsset.new(form_preview: @form_preview, relative_path: entry_path)
    asset.file.attach(io: StringIO.new(entry.get_input_stream.read), filename: entry_path.rpartition('/').last)
    asset.save!
  end

  def destroy_previous_assets
    @form_preview.preview_assets.destroy_all
  end

  def invalid_file?(entry)
    entry.name =~ Regexp.new(INVALID_FILE_NAMES.join('|'), Regexp::IGNORECASE) || !entry.file?
  end
end
