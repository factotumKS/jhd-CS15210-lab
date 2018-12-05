functor MkBigNumAdd(structure U : BIGNUM_UTIL) : BIGNUM_ADD =
struct
  structure Util = U
  open Util
  open Seq

  infix 6 ++
  exception NotYetImplemented
  exception BugInGetResult
  datatype carry = GEN | PROP | STOP
 
 (*
  * 大整数相加
  * 1）首先把两个bit串补为相同长度，方便后续计算；
  * 2）然后使用按位异或的方式得到两个串不考虑进位的“朴素和”；
  * 3）然后使用carry串储存每一位的进位信息：
  *      1+1用GEN表示；1+0用PROB表示；0+0用STOP表示
  * 4）然后在3 的基础上使用scan对进位情况进行分析，使用的结合函数为：
  *      _, GEN => GEN      如果后一位是GEN则下一位必然会进位；
  *      _, STOP => STOP    如果后一位是STOP则下以为必然不会进位；
  *      some, PROP => some 如果后一位是PROB则它传递之前的进位情况；
  *    可以得出满足结合性；
  *    scan之后得到了每一位的进位情况：
  *      GEN表示进位，STOP表示不进位，PROP不会存在；
  *    多出的一位同时表示是否溢出；
  * 5）然后把“朴素和”和“进位信息”进行map2可以得到结果：
  * 6) 最后看一下有没有溢出，如果就就在高位补充一个1就行了。
  *)
  fun x ++ y =
    case (length(x), length(y))
      of (0, 0) => empty()
       | (0, _) => y
       | (_, 0) => x
       | _ =>
    let 
      (*1、高位补零使两串等长*)
      fun with0(a : bit seq, b : bit seq) =
        let val n = Int.max(length(a), length(b))
            val taila = tabulate (fn i => ZERO) (n - length a)
            val tailb = tabulate (fn i => ZERO) (n - length b)
        in (append(a, taila), append(b, tailb))
        end;
    
      (*2、异或得到按位相加的和，不考虑进位*)
      fun bitXor(x : bit seq, y : bit seq) = 
        map2 (fn (xi, yi) => if xi = yi then ZERO else ONE) x y;
    
      (*3&4，得到进位信息，用bit表示*)
      fun getCarry(x : bit seq, y : bit seq) =
        let (*3，得到朴素carry信息*)
            fun getNaiveCarry(xi : bit, yi : bit) : carry = 
              case (xi, yi)
                of (ONE, ONE) => GEN
                 | (ZERO, ZERO) => STOP
                 | _ => PROP;
            (*4，结合函数，通过朴素carry信息推导真实carry信息*)
            fun getRealCarry(ca1 : carry, ca2 : carry) : carry= 
              case (ca1, ca2)
                of (_, GEN) => GEN
                 | (_, STOP) => STOP
                 | (some, PROP) => some;
         in 
           let 
             val naiveCarry = map2 getNaiveCarry x y
             val (realCarry, high) = scan getRealCarry STOP naiveCarry
           in 
             (realCarry, high)
           end
        end;
      (*5、直接得到结果*)
      fun getResult(x : bit seq, y : carry seq) =
        map2 (fn (i, j) => case (i, j)
                          of (ONE, GEN) => ZERO
                           | (ONE, STOP) => ONE
                           | (ZERO, GEN) => ONE
                           | (ZERO, STOP) => ZERO
                           | (_,_) => raise BugInGetResult)
              x y;
    in
      let
        val (cx, cy) = with0(x, y)
        val rawResult = bitXor(cx, cy)
        val (carryResult, high) = getCarry(cx, cy)
        val result = getResult(rawResult, carryResult)
      in
        (*6，判断高位是否溢出*)
        if high = GEN then append(result, singleton ONE)
        else rawResult 
      end
    end;

  val add = op++
end
