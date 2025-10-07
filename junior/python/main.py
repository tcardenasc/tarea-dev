from typing import List, Tuple, Dict
import json


def calculate_panels(
    panel_width: int, panel_height: int, roof_width: int, roof_height: int
) -> int:
    # Assume x,y where x >= y
    y, x = sorted((roof_width, roof_height))

    # Assume a,b where a >= b
    b, a = sorted((panel_width, panel_height))

    if min(x, y, a, b) <= 0:
        # Irrelevant cases and prevent division by 0
        return 0

    # Option 1: Fill side x along side a
    case1 = (x // a) * (y // b)
    left1 = x - (x // a) * a
    if left1 >= b:
        # Space left between panles and side y, fill with rotated panels
        case1 += (y // a) * (left1 // b)

    # Option 2: Fill side x along side b
    case2 = (x // b) * (y // a)
    left2 = y - (y // a) * a
    if left2 >= b:
        # Space left between panles and side x, fill with rotated panels
        case2 += (x // a) * (left2 // b)

    # Complexity O(1), fixed number of computations independent of input
    return max(case1, case2)


def run_tests() -> None:
    with open('test_cases.json', 'r') as f:
        data = json.load(f)
        test_cases: List[Dict[str, int]] = [
            {
                "panel_w": test["panelW"],
                "panel_h": test["panelH"],
                "roof_w": test["roofW"],
                "roof_h": test["roofH"],
                "expected": test["expected"]
            }
            for test in data["testCases"]
        ]
    
    print("Corriendo tests:")
    print("-------------------")
    
    for i, test in enumerate(test_cases, 1):
        result = calculate_panels(
            test["panel_w"], test["panel_h"], 
            test["roof_w"], test["roof_h"]
        )
        passed = result == test["expected"]
        
        print(f"Test {i}:")
        print(f"  Panels: {test['panel_w']}x{test['panel_h']}, "
              f"Roof: {test['roof_w']}x{test['roof_h']}")
        print(f"  Expected: {test['expected']}, Got: {result}")
        print(f"  Status: {'✅ PASSED' if passed else '❌ FAILED'}\n")


def main() -> None:
    print("🐕 Wuuf wuuf wuuf 🐕")
    print("================================\n")
    
    run_tests()


if __name__ == "__main__":
    main()
