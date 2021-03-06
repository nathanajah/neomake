"============================================================================
"File:        java.vim
"Description: Syntax checking plugin for neomake
"Maintainer:  Wang Shidong <wsdjeg at outlook dot com>
"License:     This program is free software. It comes without any warranty,
"             to the extent permitted by applicable law. You can redistribute
"             it and/or modify it under the terms of the Do What The Fuck You
"             Want To Public License, Version 2, as published by Sam Hocevar.
"             See http://sam.zoy.org/wtfpl/COPYING for more details.
"============================================================================


let s:save_cpo = &cpo
set cpo&vim

if exists('g:neomake_java_javac_maker')
    finish
endif
let g:neomake_java_javac_maker = 1

let g:neomake_java_javac_maven_pom_tags = ['build', 'properties']
let g:neomake_java_javac_maven_pom_properties = {}
let s:is_windows = has("win32") || has("win64") || has("win16") || has("dos32") || has("dos16")
if s:is_windows
    let s:fsep = ';'
    let s:psep = '\'
else
    let s:fsep = ':'
    let s:psep = '/'
endif
let g:neomake_java_checker_home = fnamemodify(expand('<sfile>'), ':p:h:gs?\\?/?')

" custom options
let g:neomake_java_javac_executable =
            \ get(g:, 'neomake_java_javac_executable', 'javac')

let g:neomake_java_maven_executable =
            \ get(g:, 'neomake_java_maven_executable', 'mvn')

let g:neomake_java_gradle_executable =
            \ get(g:, 'neomake_java_gradle_executable', s:is_windows? '.\gradlew.bat' : './gradlew')

let g:neomake_java_checkstyle_executable =
            \ get(g:, 'neomake_java_checkstyle_executable', 'checkstyle')

let g:neomake_java_javac_options =
            \ get(g:, 'neomake_java_javac_options', ['-Xlint'])

let g:neomake_java_maven_options =
            \ get(g:, 'neomake_java_maven_options', '')

let g:neomake_java_javac_classpath =
            \ get(g:, 'neomake_java_javac_classpath', '')

let g:neomake_java_javac_outputdir =
            \ get(g:, 'neomake_java_javac_outputdir', '')

let g:neomake_java_checkstyle_xml =
            \ get(g:, 'g:neomake_java_checkstyle_xml', '/usr/share/checkstyle/google_checks.xml')

let g:neomake_java_javac_delete_output =
            \ get(g:, 'neomake_java_javac_delete_output', 1)

let g:neomake_java_javac_autoload_maven_classpath =
            \ get(g:, 'neomake_java_javac_autoload_maven_classpath', 1)

let g:neomake_java_javac_autoload_gradle_classpath =
            \ get(g:, 'neomake_java_javac_autoload_gradle_classpath', 1)

let g:neomake_java_javac_autoload_eclipse_classpath =
            \ get(g:, 'neomake_java_javac_autoload_eclipse_classpath', 1)

let g:neomake_java_javac_maven_pom_ftime =
            \ get(g:, 'neomake_java_javac_maven_pom_ftime', {})

let g:neomake_java_javac_maven_pom_classpath =
            \ get(g:, 'neomake_java_javac_maven_pom_classpath', {})

let g:neomake_java_javac_gradle_ftime =
            \ get(g:, 'neomake_java_javac_gradle_ftime', {})

let g:neomake_java_javac_gradle_classpath =
            \ get(g:, 'neomake_java_javac_gradle_classpath', {})


let s:has_maven = executable(expand(g:neomake_java_maven_executable, 1))
let s:has_gradle = executable(expand(g:neomake_java_gradle_executable, 1))

function! s:tmpdir()
    let tempdir = ''

    if (has('unix') || has('mac')) && executable('mktemp') && !has('win32unix')
        " TODO: option "-t" to mktemp(1) is not portable
        let tmp = $TMPDIR !=# '' ? $TMPDIR : $TMP !=# '' ? $TMP : '/tmp'
        let out = split(system('mktemp -q -d ' . tmp . '/neomake-java-' . getpid() . '-XXXXXXXX'), "\n")
        if v:shell_error == 0 && len(out) == 1
            let tempdir = out[0]
        endif
    endif

    if tempdir ==# ''
        if has('win32') || has('win64')
            let tempdir = $TEMP . s:psep . 'neomake-java-' . getpid()
        elseif has('win32unix')
            let tempdir = substitute(system('cygpath -m ' . s:shescape('/neomake-java-'  . getpid())), "\n", '', 'g')
        elseif $TMPDIR !=# ''
            let tempdir = $TMPDIR . '/neomake-java-' . getpid()
        else
            let tempdir = '/tmp/neomake-java-' . getpid()
        endif

        try
            call mkdir(tempdir, 'p', 0700)
        catch /\m^Vim\%((\a\+)\)\=:E739/
            let tempdir = '.'
        endtry
    endif

    return tempdir
endfunction

function! s:ClassSep() " {{{2
    return (s:is_windows || has('win32unix')) ? ';' : ':'
endfunction " }}}2

function! s:shescape(string) abort
    return a:string =~# '\m^[A-Za-z0-9_/.-]\+$' ? a:string : shellescape(a:string)
endfunction

function! s:AddToClasspath(classpath, path)
    if a:path ==# ''
        return a:classpath
    endif
    return (a:classpath !=# '') ? a:classpath . s:ClassSep() . a:path : a:path
endfunction

function! s:ReadClassPathFile(classpathFile)
    let cp = ''
    let file = g:neomake_java_checker_home. s:psep. 'java'. s:psep.  'classpath.py'
    if has('python3')
        execute "py3file" file
        py3 import vim
        py3 vim.command("let cp = '%s'" % os.pathsep.join(ReadClasspathFile(vim.eval('a:classpathFile'))).replace('\\', '/'))
    elseif has('python')
        execute "pyfile" file
        py import vim
        py vim.command("let cp = '%s'" % os.pathsep.join(ReadClasspathFile(vim.eval('a:classpathFile'))).replace('\\', '/'))
    endif
    return cp
endfunction

function! neomake#makers#ft#java#EnabledMakers()
    let makers = []
    if executable(expand(g:neomake_java_javac_executable, 1))
        call add(makers, g:neomake_java_javac_executable)
    endif
    if executable(expand(g:neomake_java_checkstyle_executable, 1))
        call add(makers, g:neomake_java_checkstyle_executable)
    endif
    return makers
endfunction

function! neomake#makers#ft#java#javac()
    let javac_opts = extend([], g:neomake_java_javac_options)

    let output_dir = ''
    if g:neomake_java_javac_delete_output
        let output_dir = s:tmpdir()
        let javac_opts = extend(javac_opts, ['-d', s:shescape(output_dir)])
    endif

    let javac_classpath = get(g:, 'neomake_java_javac_classpath', '')

    if s:has_maven && g:neomake_java_javac_autoload_maven_classpath && empty(javac_classpath)
        if !g:neomake_java_javac_delete_output
            let javac_opts = extend(javac_opts, ['-d', s:shescape(s:MavenOutputDirectory())])
        endif
        let javac_classpath = s:AddToClasspath(javac_classpath, s:GetMavenClasspath())
    endif

    if s:has_gradle && g:neomake_java_javac_autoload_gradle_classpath && empty(javac_classpath)
        if !g:neomake_java_javac_delete_output
            let javac_opts = extend(javac_opts, ['-d', s:shescape(s:GradleOutputDirectory())])
        endif
        let javac_classpath = s:AddToClasspath(javac_classpath, s:GetGradleClasspath())
    endif

    if (has('python') || has('python3')) && empty(javac_classpath)
        let classpathFile = fnamemodify(findfile('.classpath', escape(expand('.'), '*[]?{}, ') . ';'), ':p')
        if !empty(classpathFile) && filereadable(classpathFile)
            let javac_classpath = s:ReadClassPathFile(classpathFile)
        endif
    endif

    if javac_classpath !=# ''
        let javac_opts = extend(javac_opts, ['-cp', javac_classpath])
    endif

    return {
                \ 'args': javac_opts,
                \ 'exe': g:neomake_java_javac_executable,
                \ 'buffer_output': 1,
                \ 'errorformat':
                \ '%E%f:%l: error: %m,'.
                \ '%W%f:%l: warning: %m,'.
                \ '%E%f:%l: %m,'.
                \ '%Z%p^,'.
                \ '%-G%.%#'
                \ }
endfunction

function! neomake#makers#ft#java#checkstyle()
    return {
                \ 'args': ['-c', g:neomake_java_checkstyle_xml],
                \ 'exe': g:neomake_java_checkstyle_executable,
                \ 'errorformat':
                \ '[%t%*[^]]] %f:%l:%c: %m [%s]'
                \ }
endfunction

function! s:findFileInParent(what, where) abort " {{{2
    let old_suffixesadd = &suffixesadd
    let &suffixesadd = ''
    let file = findfile(a:what, escape(a:where, ' ') . ';')
    let &suffixesadd = old_suffixesadd
    return file
endfunction " }}}2

function! s:GetMavenProperties() " {{{2
    let mvn_properties = {}
    let pom = s:findFileInParent('pom.xml', expand('%:p:h', 1))
    if s:has_maven && filereadable(pom)
        if !has_key(g:neomake_java_javac_maven_pom_properties, pom)
            let mvn_cmd = s:shescape(expand(g:neomake_java_maven_executable, 1)) .
                        \ ' -f ' . s:shescape(pom) .
                        \ ' ' . g:neomake_java_maven_options
            let mvn_is_managed_tag = 1
            let mvn_settings_output = split(system(mvn_cmd . ' help:effective-pom'), "\n")
            let current_path = 'project'
            for line in mvn_settings_output
                let matches = matchlist(line, '\m^\s*<\([a-zA-Z0-9\-\.]\+\)>\s*$')
                if mvn_is_managed_tag && !empty(matches)
                    let mvn_is_managed_tag = index(g:neomake_java_javac_maven_pom_tags, matches[1]) >= 0
                    let current_path .= '.' . matches[1]
                else
                    let matches = matchlist(line, '\m^\s*</\([a-zA-Z0-9\-\.]\+\)>\s*$')
                    if !empty(matches)
                        let mvn_is_managed_tag = index(g:neomake_java_javac_maven_pom_tags, matches[1]) < 0
                        let current_path  = substitute(current_path, '\m\.' . matches[1] . '$', '', '')
                    else
                        let matches = matchlist(line, '\m^\s*<\([a-zA-Z0-9\-\.]\+\)>\(.\+\)</[a-zA-Z0-9\-\.]\+>\s*$')
                        if mvn_is_managed_tag && !empty(matches)
                            let mvn_properties[current_path . '.' . matches[1]] = matches[2]
                        endif
                    endif
                endif
            endfor
            let g:neomake_java_javac_maven_pom_properties[pom] = mvn_properties
        endif
        return g:neomake_java_javac_maven_pom_properties[pom]
    endif
    return mvn_properties
endfunction " }}}2

function! s:GetMavenClasspath() " {{{2
    let pom = s:findFileInParent('pom.xml', expand('%:p:h', 1))
    if s:has_maven && filereadable(pom)
        if !has_key(g:neomake_java_javac_maven_pom_ftime, pom) || g:neomake_java_javac_maven_pom_ftime[pom] != getftime(pom)
            let mvn_cmd = s:shescape(expand(g:neomake_java_maven_executable, 1)) .
                        \ ' -f ' . s:shescape(pom) .
                        \ ' ' . g:neomake_java_maven_options
            let mvn_classpath_output = split(system(mvn_cmd . ' dependency:build-classpath -DincludeScope=test'), "\n")
            let mvn_classpath = ''
            let class_path_next = 0

            for line in mvn_classpath_output
                if class_path_next == 1
                    let mvn_classpath = substitute(line, "\r", '', 'g')
                    break
                endif
                if stridx(line, 'Dependencies classpath:') >= 0
                    let class_path_next = 1
                endif
            endfor

            let mvn_properties = s:GetMavenProperties()

            let output_dir = get(mvn_properties, 'project.build.outputDirectory', join(['target', 'classes'], s:psep))
            let mvn_classpath = s:AddToClasspath(mvn_classpath, output_dir)

            let test_output_dir = get(mvn_properties, 'project.build.testOutputDirectory', join(['target', 'test-classes'], s:psep))
            let mvn_classpath = s:AddToClasspath(mvn_classpath, test_output_dir)

            let g:neomake_java_javac_maven_pom_ftime[pom] = getftime(pom)
            let g:neomake_java_javac_maven_pom_classpath[pom] = mvn_classpath
        endif
        return g:neomake_java_javac_maven_pom_classpath[pom]
    endif
    return ''
endfunction " }}}2

function! s:MavenOutputDirectory() " {{{2
    let pom = s:findFileInParent('pom.xml', expand('%:p:h', 1))
    if s:has_maven && filereadable(pom)
        let mvn_properties = s:GetMavenProperties()
        let output_dir = get(mvn_properties, 'project.properties.build.dir', getcwd())

        let src_main_dir = get(mvn_properties, 'project.build.sourceDirectory', join(['src', 'main', 'java'], s:psep))
        let src_test_dir = get(mvn_properties, 'project.build.testsourceDirectory', join(['src', 'test', 'java'], s:psep))
        if stridx(expand('%:p:h', 1), src_main_dir) >= 0
            let output_dir = get(mvn_properties, 'project.build.outputDirectory', join ([output_dir, 'target', 'classes'], s:psep))
        endif
        if stridx(expand('%:p:h', 1), src_test_dir) >= 0
            let output_dir = get(mvn_properties, 'project.build.testOutputDirectory', join([output_dir, 'target', 'test-classes'], s:psep))
        endif

        if has('win32unix')
            let output_dir = substitute(system('cygpath -m ' . s:shescape(output_dir)), "\n", '', 'g')
        endif
        return output_dir
    endif
    return '.'
endfunction " }}}2

fu! s:GradleOutputDirectory()
    let gradle_build = s:findFileInParent('build.gradle', expand('%:p:h', 1))
    let items = split(gradle_build, s:psep)
    if len(items)==1
        return join(['build', 'intermediates', 'classes', 'debug'], s:psep)
    endif
    let outputdir = ''
    for i in items
        if i != 'build.gradle'
            let outputdir .= i . s:psep
        endif
    endfor
    return outputdir . join(['build', 'intermediates', 'classes', 'debug'], s:psep)
endf

fu! s:GetGradleClasspath()
    let gradle = s:findFileInParent('build.gradle', expand('%:p:h', 1))
    if s:has_gradle && filereadable(gradle)
        if !has_key(g:neomake_java_javac_gradle_ftime, gradle) || g:neomake_java_javac_gradle_ftime[gradle] != getftime(gradle)
            try
                let f = tempname()
                if s:is_windows
                    let gradle_cmd = '.\gradlew.bat'
                else
                    let gradle_cmd = './gradlew'
                endif
                call writefile(["allprojects{apply from: '" . g:neomake_java_checker_home . s:psep. 'java'. s:psep. "classpath.gradle'}"], f)
                let ret = system(gradle_cmd . ' -q -I ' . shellescape(f) . ' classpath' )
                if v:shell_error == 0
                    let cp = filter(split(ret, "\n"), 'v:val =~ "^CLASSPATH:"')[0][10:]
                    if filereadable(getcwd() . s:psep . 'build.gradle')
                        let out_putdir = s:GlobPathList(getcwd(), join(
                                    \ ['**', 'build', 'intermediates', 'classes', 'debug'],
                                    \ s:psep), 0)
                        for classes in out_putdir
                            let cp .= s:ClassSep().classes
                        endfor
                    endif
                endif
            catch
            finally
                call delete(f)
            endtry
            let g:neomake_java_javac_gradle_ftime[gradle] = getftime(gradle)
            let g:neomake_java_javac_gradle_classpath[gradle] = cp
        endif
        return g:neomake_java_javac_gradle_classpath[gradle]
    endif
    return ''
endf


function! s:GlobPathList(path, pattern, suf)
    if has("patch-7.4.279")
        return globpath(a:path, a:pattern, a:suf, 1)
    else
        return split(globpath(a:path, a:pattern, a:suf), "\n")
    endif
endfunction
let &cpo = s:save_cpo
unlet s:save_cpo
