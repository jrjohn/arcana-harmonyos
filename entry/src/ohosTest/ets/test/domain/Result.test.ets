/**
 * Unit Tests for Result Type
 */

import { describe, it, expect } from '@ohos/hypium';
import { Result, Success, Failure, ResultFactory } from '../../../../main/ets/domain/models/Result';

export default function ResultTest() {
  describe('Success', () => {
    it('should create success with value', () => {
      const success = new Success<number>(42);

      expect(success.value).assertEqual(42);
      expect(success.isSuccess).assertTrue();
      expect(success.isFailure).assertFalse();
      expect(success.kind).assertEqual('success');
    });

    it('should create success with string value', () => {
      const success = new Success<string>('hello');

      expect(success.value).assertEqual('hello');
    });

    it('should create success with object value', () => {
      const obj = { name: 'test', value: 123 };
      const success = new Success(obj);

      expect(success.value.name).assertEqual('test');
      expect(success.value.value).assertEqual(123);
    });

    it('should create success with array value', () => {
      const arr = [1, 2, 3];
      const success = new Success(arr);

      expect(success.value.length).assertEqual(3);
      expect(success.value[0]).assertEqual(1);
    });

    it('should create success with undefined value', () => {
      const success = new Success<undefined>(undefined);

      expect(success.value).assertUndefined();
      expect(success.isSuccess).assertTrue();
    });
  });

  describe('Failure', () => {
    it('should create failure with error', () => {
      const error = new Error('Something went wrong');
      const failure = new Failure<Error>(error);

      expect(failure.error.message).assertEqual('Something went wrong');
      expect(failure.isSuccess).assertFalse();
      expect(failure.isFailure).assertTrue();
      expect(failure.kind).assertEqual('failure');
    });

    it('should create failure with string error', () => {
      const failure = new Failure<string>('error message');

      expect(failure.error).assertEqual('error message');
    });

    it('should create failure with custom error type', () => {
      interface CustomError {
        code: number;
        message: string;
      }
      const customError: CustomError = { code: 404, message: 'Not found' };
      const failure = new Failure<CustomError>(customError);

      expect(failure.error.code).assertEqual(404);
      expect(failure.error.message).assertEqual('Not found');
    });
  });

  describe('ResultFactory', () => {
    describe('success', () => {
      it('should create success result', () => {
        const result = ResultFactory.success<number>(42);

        expect(result.isSuccess).assertTrue();
        expect((result as Success<number>).value).assertEqual(42);
      });
    });

    describe('failure', () => {
      it('should create failure result', () => {
        const result = ResultFactory.failure<string>('error');

        expect(result.isFailure).assertTrue();
        expect((result as Failure<string>).error).assertEqual('error');
      });
    });

    describe('map', () => {
      it('should map success value', () => {
        const original = ResultFactory.success<number>(10);
        const mapped = ResultFactory.map(original, (x) => x * 2);

        expect(mapped.isSuccess).assertTrue();
        expect((mapped as Success<number>).value).assertEqual(20);
      });

      it('should not map failure', () => {
        const original = ResultFactory.failure<string>('error');
        const mapped = ResultFactory.map<number, number, string>(original as Result<number, string>, (x) => x * 2);

        expect(mapped.isFailure).assertTrue();
        expect((mapped as Failure<string>).error).assertEqual('error');
      });

      it('should transform value type', () => {
        const original = ResultFactory.success<number>(42);
        const mapped = ResultFactory.map(original, (x) => `Value: ${x}`);

        expect(mapped.isSuccess).assertTrue();
        expect((mapped as Success<string>).value).assertEqual('Value: 42');
      });
    });

    describe('mapError', () => {
      it('should map failure error', () => {
        const original = ResultFactory.failure<string>('error');
        const mapped = ResultFactory.mapError<number, string, string>(
          original as Result<number, string>,
          (e) => `Wrapped: ${e}`
        );

        expect(mapped.isFailure).assertTrue();
        expect((mapped as Failure<string>).error).assertEqual('Wrapped: error');
      });

      it('should not map success', () => {
        const original = ResultFactory.success<number>(42);
        const mapped = ResultFactory.mapError<number, Error, string>(
          original as Result<number, Error>,
          (e) => e.message
        );

        expect(mapped.isSuccess).assertTrue();
        expect((mapped as Success<number>).value).assertEqual(42);
      });
    });

    describe('flatMap', () => {
      it('should flatMap success to success', () => {
        const original = ResultFactory.success<number>(10);
        const result = ResultFactory.flatMap(original, (x) =>
          ResultFactory.success(x * 2)
        );

        expect(result.isSuccess).assertTrue();
        expect((result as Success<number>).value).assertEqual(20);
      });

      it('should flatMap success to failure', () => {
        const original = ResultFactory.success<number>(10);
        const result = ResultFactory.flatMap<number, number, string>(
          original as Result<number, string>,
          () => ResultFactory.failure('error')
        );

        expect(result.isFailure).assertTrue();
        expect((result as Failure<string>).error).assertEqual('error');
      });

      it('should not flatMap failure', () => {
        const original = ResultFactory.failure<string>('error');
        const result = ResultFactory.flatMap<number, number, string>(
          original as Result<number, string>,
          (x) => ResultFactory.success(x * 2)
        );

        expect(result.isFailure).assertTrue();
      });
    });

    describe('getOrElse', () => {
      it('should return value for success', () => {
        const result = ResultFactory.success<number>(42);
        const value = ResultFactory.getOrElse(result, 0);

        expect(value).assertEqual(42);
      });

      it('should return default for failure', () => {
        const result = ResultFactory.failure<string>('error');
        const value = ResultFactory.getOrElse<number, string>(
          result as Result<number, string>,
          0
        );

        expect(value).assertEqual(0);
      });
    });

    describe('getOrThrow', () => {
      it('should return value for success', () => {
        const result = ResultFactory.success<number>(42);
        const value = ResultFactory.getOrThrow(result);

        expect(value).assertEqual(42);
      });

      it('should throw for failure with Error', () => {
        const result = ResultFactory.failure<Error>(new Error('test error'));
        let threw = false;
        try {
          ResultFactory.getOrThrow<number, Error>(result as Result<number, Error>);
        } catch (e) {
          threw = true;
          expect((e as Error).message).assertEqual('test error');
        }
        expect(threw).assertTrue();
      });

      it('should throw for failure with string error', () => {
        const result = ResultFactory.failure<string>('string error');
        let threw = false;
        try {
          ResultFactory.getOrThrow<number, string>(result as Result<number, string>);
        } catch (e) {
          threw = true;
        }
        expect(threw).assertTrue();
      });
    });

    describe('fold', () => {
      it('should fold success with onSuccess', () => {
        const result = ResultFactory.success<number>(10);
        const folded = ResultFactory.fold(
          result,
          (value) => `Success: ${value}`,
          (error) => `Error: ${error}`
        );

        expect(folded).assertEqual('Success: 10');
      });

      it('should fold failure with onFailure', () => {
        const result = ResultFactory.failure<string>('error');
        const folded = ResultFactory.fold<number, string, string>(
          result as Result<number, string>,
          (value) => `Success: ${value}`,
          (error) => `Error: ${error}`
        );

        expect(folded).assertEqual('Error: error');
      });
    });

    describe('fromPromise', () => {
      it('should convert resolved promise to success', async () => {
        const promise = Promise.resolve(42);
        const result = await ResultFactory.fromPromise(promise);

        expect(result.isSuccess).assertTrue();
        expect((result as Success<number>).value).assertEqual(42);
      });

      it('should convert rejected promise to failure', async () => {
        const promise = Promise.reject(new Error('promise error'));
        const result = await ResultFactory.fromPromise(promise);

        expect(result.isFailure).assertTrue();
        expect((result as Failure<Error>).error.message).assertEqual('promise error');
      });

      it('should handle non-Error rejection', async () => {
        const promise = Promise.reject('string rejection');
        const result = await ResultFactory.fromPromise(promise);

        expect(result.isFailure).assertTrue();
      });
    });

    describe('fromTry', () => {
      it('should convert successful function to success', () => {
        const result = ResultFactory.fromTry(() => 42);

        expect(result.isSuccess).assertTrue();
        expect((result as Success<number>).value).assertEqual(42);
      });

      it('should convert throwing function to failure', () => {
        const result = ResultFactory.fromTry(() => {
          throw new Error('function error');
        });

        expect(result.isFailure).assertTrue();
        expect((result as Failure<Error>).error.message).assertEqual('function error');
      });

      it('should handle non-Error throw', () => {
        const result = ResultFactory.fromTry(() => {
          throw 'string throw';
        });

        expect(result.isFailure).assertTrue();
      });
    });

    describe('combine', () => {
      it('should combine all successes', () => {
        const results: Result<number, string>[] = [
          ResultFactory.success(1),
          ResultFactory.success(2),
          ResultFactory.success(3)
        ];
        const combined = ResultFactory.combine(results);

        expect(combined.isSuccess).assertTrue();
        const values = (combined as Success<number[]>).value;
        expect(values.length).assertEqual(3);
        expect(values[0]).assertEqual(1);
        expect(values[1]).assertEqual(2);
        expect(values[2]).assertEqual(3);
      });

      it('should return first failure', () => {
        const results: Result<number, string>[] = [
          ResultFactory.success(1),
          ResultFactory.failure('error'),
          ResultFactory.success(3)
        ];
        const combined = ResultFactory.combine(results);

        expect(combined.isFailure).assertTrue();
        expect((combined as Failure<string>).error).assertEqual('error');
      });

      it('should handle empty array', () => {
        const results: Result<number, string>[] = [];
        const combined = ResultFactory.combine(results);

        expect(combined.isSuccess).assertTrue();
        expect((combined as Success<number[]>).value.length).assertEqual(0);
      });
    });
  });
}
