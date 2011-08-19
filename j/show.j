# showing fundamental objects

print(x) = show(x)
shown(x) = print_to_string(show, x)

show(s::Symbol) = print(s)
show(tn::TypeName) = show(tn.name)
show(::Nothing) = print("nothing")

function show_delim_array(itr, open, delim, close, delim_one)
    print(open)
    state = start(itr)
    newline = true
    first = true
    if !done(itr,state)
	while true
	    x, state = next(itr,state)
            multiline = isa(x,AbstractArray) && ndims(x)>1 && numel(x)>0
            if newline
                if multiline; println(); end
            end
	    show(x)
	    if done(itr,state)
                if delim_one && first
                    print(delim)
                end
		break
	    end
            first = false
            print(delim)
            if multiline
                println(); newline=false
            else
                newline = true
            end
	end
    end
    print(close)
end

show_comma_array(itr, o, c) = show_delim_array(itr, o, ',', c, false)

function show(t::Tuple)
    show_delim_array(t, '(', ',', ')', true)
end

function show_expr_type(ty)
    if !is(ty, Any)
        if isa(ty, FuncKind)
            print("::F")
        elseif is(ty, IntrinsicFunction)
            print("::I")
        else
            print("::$ty")
        end
    end
end

function show(e::Expr)
    hd = e.head
    if is(hd,:call)
        print(e.args[1])
        show_comma_array(e.args[2:],'(',')')
    elseif is(hd,:(=))
        print("$(e.args[1]) = $(e.args[2])")
    elseif is(hd,:quote)
        a1 = e.args[1]
        if isa(e.args[1],Expr) && (is(a1.head,:body) ||
                                   is(a1.head,:block))
            println("\nquote")
            for a=a1.args
                println("  $a")
            end
            println("end")
        else
            if isa(a1,Symbol) && !is(a1,:(:))
                print(":$a1")
            else
                print(":($a1)")
            end
        end
    elseif is(hd,:null)
        print("nothing")
    elseif is(hd,:goto)
        print("goto $(e.args[1])")
    elseif is(hd,:gotoifnot)
        print("unless $(e.args[1]) goto $(e.args[2])")
    elseif is(hd,:return)
        print("return $(e.args[1])")
    elseif is(hd,:string)
        show(e.args[1])
    elseif is(hd,symbol("::"))
        print("$(e.args[1])::$(e.args[2])")
    elseif is(hd,:body) || is(hd,:block)
        print("\nbegin\n")
        for a=e.args
            println("  $a")
        end
        println("end")
    elseif is(hd,:comparison)
        print(e.args...)
    elseif is(hd,:(.))
        print(e.args[1],'.',e.args[2])
    else
        print(hd)
        show_comma_array(e.args,'(',')')
    end
    show_expr_type(e.type)
end

function show(e::SymbolNode)
    print(e.name)
    show_expr_type(e.type)
end

function show(e::LineNumberNode)
    print("line($(e.line))")
end

function show(e::LabelNode)
    print("$(e.label): ")
end

function show(e::TypeError)
    ctx = isempty(e.context) ? "" : "in $(e.context), "
    if e.expected == Bool
        print("type error: non-boolean ($(typeof(e.got))) ",
              "used in boolean context")
    else
        print("type error: $(e.func): ",
              "$(ctx)expected $(e.expected), ",
              "got $(typeof(e.got))")
    end
end

function show(e::LoadError)
    show(e.error)
    print(" $(e.file):$(e.line)")
end

show(e::SystemError) = print("$(e.prefix): $(strerror(e.errnum))")
show(::DivideByZeroError) = print("error: integer divide by zero")
show(::StackOverflowError) = print("error: stack overflow")
show(::UndefRefError) = print("access to undefined reference")
show(::EOFError) = print("read: end of file")
show(e::ErrorException) = print(e.msg)
show(e::KeyError) = print("key not found: $(e.key)")
show(e::InterruptException) = nothing

function show(e::MethodError)
    name = ccall(:jl_genericfunc_name, Any, (Any,), e.f)
    if is(e.f,convert)
        print("no method $(name)(Type{$(e.args[1])},$(typeof(e.args[2])))")
    else
        print("no method $(name)$(typeof(e.args))")
    end
end

function show(e::UnionTooComplexError)
    print("union type pattern too complex: ")
    show(e.types)
end

function show(bt::BackTrace)
    show(bt.e)
    i = 1
    t = bt.trace
    while i < length(t)
        println()
        lno = t[i+2]
        if lno < 1
            line = ""
        else
            line = ":$lno"
        end
        print("in $(t[i]), $(t[i+1])$line")
        i += 3
    end
end

function dump(x)
    T = typeof(x)
    if isa(x,Array)
        print("Array($(eltype(x)),$(size(x)))")
    elseif isa(T,CompositeKind)
        print(T,'(')
        for field = T.names
            print(field, '=')
            dump(getfield(x, field))
            print(',')
        end
        println(')')
    else
        show(x)
    end
end

function showall{T}(a::AbstractArray{T,1})
    if is(T,Any)
        opn = '{'; cls = '}'
    else
        opn = '['; cls = ']';
    end
    show_comma_array(a, opn, cls)
end

function showall_matrix(a::AbstractArray)
    for i = 1:size(a,1)
        show_cols(a, 1, size(a,2), i)
        print('\n')
    end
end

function showall{T}(a::AbstractArray{T,2})
    print(summary(a))
    if isempty(a)
        return
    end
    println()
    showall_matrix(a)
end

function show{T}(a::AbstractArray{T,1})
    if is(T,Any)
        opn = '{'; cls = '}'
    else
        opn = '['; cls = ']';
    end
    n = size(a,1)
    if n <= 10
        show_comma_array(a, opn, cls)
    else
        show_comma_array(a[1:5], opn, "")
        print(",...,")
        show_comma_array(a[(n-4):n], "", cls)
    end
end

function show_cols(a, start, stop, i)
    for j = start:stop
        show(a[i,j])
        print(' ')
    end
end

function show{T}(a::AbstractArray{T,2})
    print(summary(a))
    if isempty(a)
        return
    end
    println()
    show_matrix(a)
end

function show_matrix(a::AbstractArray)
    m = size(a,1)
    n = size(a,2)
    print_hdots = false
    print_vdots = false
    if 10 < m; print_vdots = true; end
    if 10 < n; print_hdots = true; end
    if !print_vdots && !print_hdots
        for i = 1:m
            show_cols(a, 1, n, i)
            if i < m; println(); end
        end
    elseif print_vdots && !print_hdots
        for i = 1:3
            show_cols(a, 1, n, i)
            println()
        end
        println(':')
        for i = m-2:m
            show_cols(a, 1, n, i)
            if i < m; println(); end
        end
    elseif !print_vdots && print_hdots
        for i = 1:m
            show_cols(a, 1, 3, i)
            if i == 1 || i == m; print(": "); else; print("  "); end
            show_cols(a, n-2, n, i)
            if i < m; println(); end
        end
    else
        for i = 1:3
            show_cols(a, 1, 3, i)
            if i == 1; print(": "); else; print("  "); end
            show_cols(a, n-2, n, i)
            println()
        end
        print(":\n")
        for i = m-2:m
            show_cols(a, 1, 3, i)
            if i == m; print(": "); else; print("  "); end
            show_cols(a, n-2, n, i)
            if i < m; println(); end
        end
    end
end

show{T}(a::AbstractArray{T,0}) = print(summary(a))

function show(a::AbstractArray)
    print(summary(a))
    if isempty(a)
        return
    end
    println()
    tail = size(a)[3:]
    nd = ndims(a)-2
    function print_slice(idxs)
        for i = 1:nd
            ii = idxs[i]
            if size(a,i+2) > 10
                if ii == 4 && allp(x->x==1,idxs[1:i-1])
                    for j=i+1:nd
                        szj = size(a,j+2)
                        if szj>10 && 3 < idxs[j] <= szj-3
                            return
                        end
                    end
                    #println(idxs)
                    print("...\n\n")
                    return
                end
                if 3 < ii <= size(a,i+2)-3
                    return
                end
            end
        end
        print("[:, :, ")
        for i = 1:(nd-1); print("$(idxs[i]), "); end
        println(idxs[end], "] =")
        show_matrix(a[:,:,idxs...])
        print(idxs == tail ? "" : "\n\n")
    end
    cartesian_map(print_slice, map(x->Range1(1,x), tail))
end

function showall(a::AbstractArray)
    print(summary(a))
    if isempty(a)
        return
    end
    println()
    tail = size(a)[3:]
    nd = ndims(a)-2
    function print_slice(idxs)
        print("[:, :, ")
        for i = 1:(nd-1); print("$(idxs[i]), "); end
        println(idxs[end], "] =")
        showall_matrix(a[:,:,idxs...])
        print(idxs == tail ? "" : "\n\n")
    end
    cartesian_map(print_slice, map(x->Range1(1,x), tail))
end

summary(x) = string(typeof(x))

function dims2string(d)
    if length(d) == 0
        return "0-dimensional"
    elseif length(d) == 1
        strcat(d[1], "-element")
    else
        join("x", map(string,d))
    end
end

summary{T}(a::AbstractArray{T}) = strcat(dims2string(size(a)),
                                         " ", string(T), " ",
                                         string(typeof(a).name))

function whos()
    global VARIABLES
    for v = map(symbol,sort(map(string, VARIABLES)))
        if isbound(v)
            println(rpad(v, 30), summary(eval(v)))
        end
    end
end
