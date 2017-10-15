__precompile__()

module BuildUtils

using Compat
using Compat.Sys: iswindows, isapple

export rpath_origin, whole_archive, isexecutable, object_dependencies

"""
    rpath_origin([kernel]; escape=false)

Construct the appropriate linker flags used for setting the runtime search to include
`\$ORIGIN`, the location of the library itself that's looking for a required dependency.
If `escape` is `true`, the leading `\$` in `\$ORIGIN` is doubled. This sometimes useful
since `\$` has a special meaning in the shell.
"""
function rpath_origin(k::Symbol=Sys.KERNEL; escape::Bool=false)
    if isapple(k)
        "-Wl,-rpath,'@loader_path/'"
    elseif iswindows(k)
        ""
    else
        flags = "-Wl,-rpath,'\$ORIGIN' -Wl,-z,origin"
        escape ? replace(flags, '$', "\$\$") : flags
    end
end

"""
    whole_archive([kernel], lib)

Wrap the static library `lib`, specified as a `String`, in "whole archive" and
"no whole archive" flags.
"""
function whole_archive(k::Symbol, lib::String)
    if isapple(k)
        whole = "-Xlinker -all_load"
        nowhole = ""
    else
        whole = "-Wl,--whole-archive"
        nowhole = "-Wl,--no-whole-archive"
    end
    chomp(string(whole, " ", s, " ", nowhole))
end

"""
    isexecutable(program)

Determine whether the given program name or path is executable using the current user's
permissions. This is roughly equivalent to querying `which program` at the command line
and checking that a result is found, but no shelling out occurs.
"""
function isexecutable(k::Symbol, prog::String)
    access = iswindows(k) ? :_access : :access
    X_OK = 1 << 0 # Taken from unistd.h
    # If prog has a slash, we know the user wants to determine whether the given
    # file exists and is executable
    if '/' in prog || (iswindows(k) && '\\' in prog) # Windows can use / too
        isfile(prog) || return false
        return ccall(access, Cint, (Ptr{UInt8}, Cint), prog, X_OK) == 0
    end
    path = get(ENV, "PATH", "")
    # Something is definitely wrong if the user's path is empty...
    @assert !isempty(path)
    sep = iswindows(k) ? ';' : ':'
    for dir in split(path, sep), file in readdir(dir)
        if file == prog || (iswindows(k) && file == prog * ".exe")
            p = joinpath(dir, file)
            @assert isfile(p)
            return ccall(access, Cint, (Ptr{UInt8}, Cint), p, X_OK) == 0
        end
    end
    false
end

"""
    object_dependencies([kernel,] lib)

Determine the shared libraries on which the given library `lib` depends, returning
a `Dict` of library, path pairs.

!!! note
    This function shells out to `otool -L` on macOS, which requires having the Xcode
    command line tools installed. On other systems, it shells out to `ldd`, which
    can be installed with system package managers if it isn't already installed on
    the system.
"""
function object_dependencies(k::Symbol, lib::String)
    isfile(lib) || throw(ArgumentError("library '$lib' does not exist"))
    if isapple(k)
        isexecutable(k, "otool") || error("otool is not available")
        cmd = `otool -L`
    else
        isexecutable(k, "ldd") || error("ldd is not available")
        cmd = `ldd`
    end
    d = Dict{String,String}()
    # The first line is always the input library
    for line in Iterators.drop(eachline(`$cmd $lib`), 1)
        line = lstrip(line)
        # TODO: Move this check out of the loop?
        if isapple(k)
            found = line[1:prevind(line, findfirst(line, ' '))]
            dep = basename(found)
        else
            tokens = split(line)
            length(tokens) == 4 || error("unexpected line format: '$line'")
            dep = tokens[1]
            # Handle 'not found'
            found = tokens[3] == "not" ? join(tokens[3:4], ' ') : tokens[3]
        end
        d[dep] = found
    end
    d
end

for f in [:whole_archive, :isexecutable, :object_dependencies]
    @eval ($f)(s::String) = ($f)(Sys.KERNEL, s)
end

end # module
