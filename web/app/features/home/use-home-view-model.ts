import { useState, useCallback } from "react";

/**
 * Home 화면의 ViewModel. 상태·비즈니스 로직을 보유하고 View(React 컴포넌트)에
 * 읽기 전용 상태 + 액션만 노출한다. 로케일 의존적인 기본 문자열은 View가
 * i18n에서 가져오고, ViewModel은 override된 값만 노출한다.
 */
export function useHomeViewModel() {
  const [greeting, setGreeting] = useState<string | null>(null);

  const updateGreeting = useCallback((value: string | null) => {
    setGreeting(value);
  }, []);

  return { greeting, updateGreeting } as const;
}

export type HomeViewModel = ReturnType<typeof useHomeViewModel>;
