require File.expand_path("../chors.rb", __FILE__)

class Experiment
  def initialize(chroma_algorithm: :stft, templates: :bin,
                 normalize_templates: nil, normalize_chromas: :inf,
                 smooth_frames: 0, post_filtering: false, verbose: true)
    @templates = TemplateBank.new(
      binary: templates == :bin,
      chroma_algorithm: chroma_algorithm,
      normalize: normalize_templates
    )

    @chroma_algorithm = chroma_algorithm
    @normalize_chromas = normalize_chromas
    @smooth_frames = smooth_frames
    @post_filtering = post_filtering

    @verbose = verbose
  end

  def id
    @id ||= [
      @chroma_algorithm,
      @templates.name,
      @templates.normalize?,
      @normalize_chromas,
      @smooth_frames,
      @post_filtering
    ].map { |attribute| attribute || "nil" }.join("_")
  end

  def description
    @description ||= <<~TXT
      Chord Recognition experiment with the following parameters:

      \tchroma_algorithm     => #{@chroma_algorithm}
      \ttemplates            => #{@templates}
      \tnormalize_templates  => #{@normalize_templates}
      \tnormalize_chromas    => #{@normalize_chromas}
      \tsmooth_frames        => #{@smooth_frames}
      \tpost_filtering       => #{@post_filtering}

    TXT
  end

  def results
    @results ||= already_ran? ? load_results : run
  end

  def directory
    @directory ||= File.expand_path("../../experiments/#{id}", __FILE__)
  end

  def recognition_params
    [
      @templates,
      {
        chroma_algorithm: @chroma_algorithm,
        normalize_chromas: @normalize_chromas,
        smooth_frames: @smooth_frames,
        post_filtering: @post_filtering
      }
    ]
  end

  private

  def already_ran?
    File.exists?(path_of :results)
  end

  def run
    results = {}

    total_folds = @templates.songs.size
    @templates.songs.each_with_index do |song_list, fold|
      total_songs = song_list.size
      fold_results = song_list.map.with_index do |song, i|
        if @verbose
          percent = 1.0 * (i + 1) * (fold + 1) / (total_songs * total_folds)
          puts "running #{id}: #{(percent * 100).round(2).to_s.rjust(6, ' ')}%"
        end

        song.evaluation(self)
      end

      fold_results

      results["fold#{fold}"] = average(fold_results)
    end

    save_results(results)
    save_description

    results
  end

  def average(results)
    size = results.size
    precision = recall = f_measure = 0

    results.each do |result|
      precision += result['precision']
      recall += result['recall']
      f_measure += result['f_measure']
    end

    {
      'precision' => precision.to_f / size,
      'recall' => recall.to_f / size,
      'f_measure' => f_measure.to_f / size
    }
  end

  def save_description
    File.open(path_of(:description, :txt), "w") { |f| f << description }
  end

  def save_results(results)
    File.open(results_path, "w") { |f| f << results.to_yaml }
  end

  def load_results
    YAML.load(File.read results_path)
  end

  def results_path
    path_of :results
  end

  def path_of(file, file_format=:yml)
    "#{directory}/#{[file].flatten.join("/")}.#{file_format}"
  end
end