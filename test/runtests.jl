using BuiltUtils
using Base.Test

@testset "rpath" begin
    # macOS
    @test rpath_origin(:Darwin) == "-Wl,-rpath,'@loader_path/'"
    @test rpath_origin(:Darwin, escape=true) == rpath_origin(:Darwin, escape=false)

    # Windows
    @test rpath_origin(:NT, escape=true) == rpath_origin(:NT, escape=false) == ""

    # Everything else
    @test rpath_origin(:Linux) == "-Wl,-rpath,'\$ORIGIN' -Wl,-z,origin"
    @test rpath_origin(:Linux) == rpath_origin(:FreeBSD)
    @test rpath_origin(:Solaris, escape=true) == "-Wl,-rpath,'\$\$ORIGIN' -Wl,-z,origin"
end

@testset "whole archive" begin
    lib = "/path/to/nowhere.so"
    @test whole_archive(:Darwin, lib) == "-Xlinker -all_load " * lib
    @test whole_archive(:NT, lib) == "-Wl,--whole-archive " * lib * " -Wl,--no-whole-archive"
end

@testset "is executable" begin
    @test isexecutable("sh")  # Everyone should have sh, so though should be safe
    @test !isexecutable("./wacky-whatever.txt")
end

@testset "ldd" begin
    d = object_dependencies(Libdl.dlpath("libjulia"))
    @test d isa Dict{String,String}
    @test any(k->contains(k, "libLLVM"), keys(d))
end
