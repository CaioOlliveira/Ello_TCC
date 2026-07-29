const oneDayMs = 24 * 60 * 60 * 1000;

export const parseLocalDate = (value?: string): Date => {
  if (!value) return new Date();

  const [year, month, day] = value.split("-").map((part) => Number(part));
  if (!year || !month || !day) return new Date(value);

  return new Date(year, month - 1, day, 12, 0, 0, 0);
};

export const startOfLocalDay = (date: Date): Date => {
  const copy = new Date(date);
  copy.setHours(0, 0, 0, 0);
  return copy;
};

export const addLocalDays = (date: Date, days: number): Date => {
  const copy = new Date(date);
  copy.setDate(copy.getDate() + days);
  return copy;
};

export const localDayRange = (
  date: Date,
): { start: Date; endExclusive: Date } => {
  const start = startOfLocalDay(date);
  return { start, endExclusive: addLocalDays(start, 1) };
};

export const sameLocalDay = (value: Date, reference: Date): boolean =>
  value.getFullYear() === reference.getFullYear() &&
  value.getMonth() === reference.getMonth() &&
  value.getDate() === reference.getDate();

export const formatLocalDate = (date: Date): string => {
  const year = date.getFullYear().toString().padStart(4, "0");
  const month = (date.getMonth() + 1).toString().padStart(2, "0");
  const day = date.getDate().toString().padStart(2, "0");
  return `${year}-${month}-${day}`;
};

export const isFutureInstant = (
  value: string,
  toleranceMs = 60 * 1000,
): boolean => {
  const parsed = new Date(value);
  return (
    !Number.isNaN(parsed.getTime()) &&
    parsed.getTime() > Date.now() + toleranceMs
  );
};

export const periodRange = <T extends "dia" | "semanal" | "mes">(
  reference: Date,
  period: T,
): { start: Date; endExclusive: Date } => {
  const { start } = localDayRange(reference);

  if (period === "semanal") {
    return {
      start: addLocalDays(start, -6),
      endExclusive: addLocalDays(start, 1),
    };
  }

  if (period === "mes") {
    return {
      start: addLocalDays(start, -29),
      endExclusive: addLocalDays(start, 1),
    };
  }

  return {
    start,
    endExclusive: addLocalDays(start, 1),
  };
};

export const dayDifference = (start: Date, end: Date): number =>
  Math.round(
    (startOfLocalDay(end).getTime() - startOfLocalDay(start).getTime()) /
      oneDayMs,
  );

export const calculateAge = (
  birthDate: Date,
  reference = new Date(),
): number => {
  let age = reference.getFullYear() - birthDate.getFullYear();
  const birthdayAlreadyPassed =
    reference.getMonth() > birthDate.getMonth() ||
    (reference.getMonth() === birthDate.getMonth() &&
      reference.getDate() >= birthDate.getDate());

  if (!birthdayAlreadyPassed) age -= 1;
  return Math.max(age, 0);
};
