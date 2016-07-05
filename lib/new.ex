defmodule Mix.Tasks.Ejabberd.New do
  use Mix.Task

  import Mix.Generator
  import Mix.Utils, only: [camelize: 1]

  @shortdoc "Creates a new ejabberd project"

  @moduledoc """
  Creates a new ejabberd project.

  It expects the path of the project as argument.

      mix ejabberd.new PATH [--sup] [--module MODULE] [--app APP]

  A project at the given PATH  will be created. The
  application name and module name will be retrieved
  from the path, unless `--module` or `--app` is given.

  ## Options

  - A `--sup` - option can be given to generate an OTP application skeleton including a
    supervision tree. Normally an app is generated without a supervisor and without
    the app callback.

  - An `--app` - option can be given in order to name the OTP application for the
    project.

  - A `--module` option can be given in order to name the modules in the generated
    code skeleton.

  - A `--no-exconfig` - option can be given in order to use the old .yml configuration
    file instead.
  """

  @ejabberd_version "16.4.1"
  @switches [sup: :boolean, app: :string, module: :string, no_exconfig: :boolean]

  def run(argv) do
    {opts, argv} = OptionParser.parse!(argv, strict: @switches)

    case argv do
      [] ->
        Mix.raise "Expected PATH to be given, please use \"mix ejabberd.new PATH\""
      [path | _] ->
        app = opts[:app] || Path.basename(Path.expand(path))
        check_application_name!(app, !!opts[:app])
        mod = opts[:module] || camelize(app)
        check_mod_name_validity!(mod)
        check_mod_name_availability!(mod)
        File.mkdir_p!(path)

      File.cd! path, fn ->
        do_generate(app, mod, path, opts)
      end
    end
  end

  defp do_generate(app, mod, path, opts) do
    assigns = [app: app, mod: mod,
    no_exconfig: opts[:no_exconfig],
    otp_app: otp_app(mod, !!opts[:sup]),
    version: get_version(System.version),
    ejabberd_version: @ejabberd_version]

    create_file "README.md",  readme_template(assigns)
    create_file ".gitignore", gitignore_text

    create_file "mix.exs", mixfile_template(assigns)

    create_directory "config"
    create_file "config/config.exs", config_template(assigns)

    if opts[:no_exconfig] do
      create_file "config/ejabberd.yml", config_ejabberd_yml_template(assigns)
    else
      create_file "config/ejabberd.exs", config_ejabberd_template(assigns)
    end

    create_directory "lib"

    if opts[:sup] do
      create_file "lib/#{app}.ex", lib_sup_template(assigns)
    else
      create_file "lib/#{app}.ex", lib_template(assigns)
    end

    create_directory "logs"

    create_directory "test"
    create_file "test/test_helper.exs", test_helper_template(assigns)
    create_file "test/#{app}_test.exs", test_template(assigns)

    install? = Mix.shell.yes?("\nFetch and install dependencies?")
    if install? do
      Mix.shell.info [:green, "* info ", :reset, "Running mix deps.get"]
      System.cmd("mix", ["deps.get"])
    end

    # Leave a blank line to separate from previous prompt: "fetch deps?""
    Mix.shell.info """

    Your ejabberd project was created successfully!
    Run your application with:

        $ cd #{path}
        $ iex -S mix

    To add a module to ejabberd, or to change a configuration
    parameter, you have to change the configuration file.

    You can find the configuration file of ejabberd into
    the /config folder.

    Visit https://docs.ejabberd.im/ for more informations
    """
  end

  defp otp_app(_mod, false) do
    "    [applications: [:logger, :ejabberd]]"
  end

  defp otp_app(mod, true) do
    "    [applications: [:logger, :ejabberd],\n     mod: {#{mod}, []}]"
  end

  defp check_application_name!(name, from_app_flag) do
    unless name =~ ~r/^[a-z][\w_]*$/ do
      Mix.raise "Application name must start with a letter and have only lowercase " <>
      "letters, numbers and underscore, got: #{inspect name}" <>
      (if !from_app_flag do
         ". The application name is inferred from the path, if you'd like to " <>
         "explicitly name the application then use the \"--app APP\" option."
      else
        ""
      end)
    end
  end

  defp check_mod_name_validity!(name) do
    unless name =~ ~r/^[A-Z]\w*(\.[A-Z]\w*)*$/ do
      Mix.raise "Module name must be a valid Elixir alias (for example: Foo.Bar), got: #{inspect name}"
    end
  end

  defp check_mod_name_availability!(name) do
    name = Module.concat(Elixir, name)
    if Code.ensure_loaded?(name) do
      Mix.raise "Module name #{inspect name} is already taken, please choose another name"
    end
  end

  defp get_version(version) do
    {:ok, version} = Version.parse(version)
    "#{version.major}.#{version.minor}" <>
    case version.pre do
      [h | _] -> "-#{h}"
      []      -> ""
    end
  end

  embed_template :readme, File.read! "./lib/templates/readme.md"
  embed_text :gitignore, File.read! "./lib/templates/gitignore"
  embed_template :mixfile, File.read! "./lib/templates/mix.exs"
  embed_template :config, File.read! "./lib/templates/config.exs"
  embed_template :lib, File.read! "./lib/templates/lib.exs"
  embed_template :lib_sup, File.read! "./lib/templates/lib_sup.exs"
  embed_template :test, File.read! "./lib/templates/test.exs"
  embed_template :test_helper, File.read! "./lib/templates/test_helper.exs"
  embed_template :config_ejabberd, File.read! "./lib/templates/config_ejabberd.exs"
  embed_template :config_ejabberd_yml, File.read! "./lib/templates/config_ejabberd_yml.yml"
end
