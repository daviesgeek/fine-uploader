spawn = require('child_process').spawn
path = require 'path'
grunt = require 'grunt'
_ = grunt.util._
modules = require '../modules'

module.exports =

  checkPullRequest: ->
    if (process.env.TRAVIS_BRANCH == 'master' and process.env.TRAVIS_PULL_REQUEST != 'false')
      grunt.fail.fatal '''Woah there, buddy! Pull requests should be
      branched from develop!\n
      Details on contributing pull requests found here: \n
      https://github.com/Widen/fine-uploader/blob/master/CONTRIBUTING.md\n
      '''

  startKarma: (config, singleRun, done) ->
    browsers = grunt.option 'browsers'
    reporters = grunt.option 'reporters'
    port = grunt.option 'port'
    args = ['node_modules/karma/bin/karma', 'start', config,
      if singleRun then '--single-run=true' else '',
      if reporters then '--reporters=' + reporters else '',
      if browsers then '--browsers=' + browsers else '',
      if port then '--port=' + port else ''
    ]
    p = spawn 'node', args
    p.stdout.pipe process.stdout
    p.stderr.pipe process.stderr
    p.on 'exit', (code) ->
      if code != 0
        grunt.fail.warn "Karma test(s) failed. Exit code: " + code
      done()

  parallelTask: (args, options) ->
    task =
      grunt: true
      args: args
      stream: options && options.stream

    args.push '--port=' + @sauceLabsAvailablePorts.pop()

    if grunt.option 'reporters'
      args.push '--reporters=' + grunt.option 'reporters'

    task

  sauceLabsAvailablePorts: [9000, 9001, 9080, 9090, 9876]

  concat: (formulae) ->
    src = ''
    _.map(formulae, (f) ->
      src = grunt.file.read f
      src
    ).join(grunt.util.linefeed)

  build: (dest, formulae) ->
    ###
    This task will generate a custom build of Fine Uploader based on the
    provided `formulae`
    These formulae correspond to the keys in './lib/modules'
    and are combined into the `dest` directory.
    ###

    dest_src = path.join(dest, 'src')
    filename = grunt.config.process 'custom.<%= pkg.name %>-<%= pkg.version %>.js'
    dest_filename = path.join(dest, 'src', filename)

    # Build formula, true indicates that module should be included
    formula = []
    includes =
      fuCoreTraditional: false
      fuCoreS3: false
      fuUiTraditional: false
      fuUiS3: false
      fuSrcJquery: false
      fuSrcS3Jquery: false
    ###
    Soon to be included formulae
    includes =
      fuSrcCore: true
      fuSrcUiModules: false
      fuPasteModule: false
      fuDndModule: false
      fuUiModules: false
      fuDeleteFileModule: false
      fuDeleteFileUiModule: false
      fuEditFilenameModule: false
      fuSrcModules: false
      fuSrcUi: false
      fuSrcJquery: false
      fuSrcTraditional: false
      fuSrcS3: false
      fuSrcS3Jquery: false
    ###

    extraIncludes =
      fuDocs: true
      fuImages: true
      fuCss: true
      fuIframeXssResponse: true

    if _.isArray formulae
      _.each formulae, (mod) ->
        if mod in _.keys(includes)
          includes[mod] = true
    else if _.isObject formulae
      includes = _.defaults includes, formulae

    formula = _.filter _.keys(includes), (k) -> includes[k] is true
    mods = modules.mergeModules.apply @, formula

    src = @concat mods
    grunt.file.write dest_filename, src
    grunt.log.writeln "Wrote: " + dest_filename

    extraFormula = _.filter _.keys(extraIncludes), (k) -> extraIncludes[k] is true
    extraModules = modules.mergeModules.apply @, extraFormula

    _.each extraModules, (mod) ->
      modname = path.basename(mod)
      if modname.match(/\.css$/)
        modname = grunt.config.process 'custom.<%= pkg.name %>-<%= pkg.version %>.css'
      grunt.file.copy mod, path.join(dest_src, modname)
      grunt.log.writeln "Copied: #{path.basename(modname)}"
