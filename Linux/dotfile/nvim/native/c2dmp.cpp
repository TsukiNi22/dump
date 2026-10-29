/**************************************************************\

 ██╗  ██╗ █████╗ ██████╗ ████████╗ █████╗ ███╗   ██╗██╗ █████╗
 ╚██╗██╔╝██╔══██╗██╔══██╗╚══██╔══╝██╔══██╗████╗  ██║██║██╔══██╗
  ╚███╔╝ ███████║██████╔╝   ██║   ███████║██╔██╗ ██║██║███████║
  ██╔██╗ ██╔══██║██╔══██╗   ██║   ██╔══██║██║╚██╗██║██║██╔══██║
 ██╔╝ ██╗██║  ██║██║  ██║   ██║   ██║  ██║██║ ╚████║██║██║  ██║
 ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝

File Name:
##  @file c2dmp.cpp

File Description:
##  C ABI of c2dmp-hsm (libutils, normal mode) loaded by neovim through LuaJIT ffi
\**************************************************************/

//----------------------------------------------------------------//
/* INCLUDE */

#include "utils/algorithms/c2dmp-hsm/c2dmp-hsm.hpp" // utils::algorithms::c2dmp::c2dmp
#include <string_view> // std::string_view
#include <cstddef>     // std::size_t

//----------------------------------------------------------------//
/* FUNCTION */

/* distance between the typed word (a) and a candidate (b), the lower the closer (same word = -10, not full) */
extern "C" float c2dmp_distance(const char* a, std::size_t sizeA, const char* b, std::size_t sizeB) {
    return utils::algorithms::c2dmp::c2dmp<>(std::string_view(a, sizeA), std::string_view(b, sizeB));
}
