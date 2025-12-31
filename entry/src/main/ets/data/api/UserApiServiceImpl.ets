/**
 * Injectable User API Service
 * Implements IUserApiService interface for DI container
 */

import { http } from '@kit.NetworkKit';
import { injectable, preDestroy } from '../../core/di/decorators';
import { IUserApiService, ILogger } from '../../core/di/interfaces';
import { ApiConfig, ApiEndpoints, ApiHeaders, HttpStatus } from './ApiConfig';
import {
  PaginatedUsersResponse,
  SingleUserResponse,
  CreateUserResponseDto,
  UpdateUserResponseDto,
  UserDtoMapper
} from './dto/UserDto';
import { User, CreateUserRequest, UpdateUserRequest, PaginatedUsers } from '../../domain/models/User';
import { Result, ResultFactory } from '../../domain/models/Result';
import { AppError, AppErrorFactory } from '../../domain/models/AppError';

const TAG = 'UserApiServiceImpl';

/**
 * Injectable user API service implementation
 */
@injectable()
export class UserApiServiceImpl implements IUserApiService {
  private httpRequest: http.HttpRequest;
  private logger?: ILogger;

  constructor() {
    this.httpRequest = http.createHttp();
  }

  /**
   * Sets the logger (for manual injection)
   */
  setLogger(logger: ILogger): void {
    this.logger = logger;
  }

  async getUsers(page: number = 1, perPage: number = 6): Promise<Result<PaginatedUsers, AppError>> {
    const url = `${ApiConfig.BASE_URL}${ApiEndpoints.USERS}?page=${page}&per_page=${perPage}`;
    this.log(`Fetching users from: ${url}`);

    try {
      const response = await this.httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: this.getHeaders(),
        connectTimeout: ApiConfig.TIMEOUT,
        readTimeout: ApiConfig.TIMEOUT
      });

      if (response.responseCode === HttpStatus.OK) {
        const data = JSON.parse(response.result as string) as PaginatedUsersResponse;
        this.log(`Successfully fetched ${data.data.length} users`);
        return ResultFactory.success(UserDtoMapper.toPaginatedDomain(data));
      } else {
        this.logError(`API error: ${response.responseCode}`);
        return ResultFactory.failure(AppErrorFactory.fromHttpStatus(response.responseCode));
      }
    } catch (error) {
      this.logError(`Network error fetching users: ${error}`);
      return ResultFactory.failure(this.handleError(error));
    }
  }

  async getUser(userId: number): Promise<Result<User, AppError>> {
    const url = `${ApiConfig.BASE_URL}${ApiEndpoints.userById(userId)}`;
    this.log(`Fetching user ${userId} from: ${url}`);

    try {
      const response = await this.httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: this.getHeaders(),
        connectTimeout: ApiConfig.TIMEOUT,
        readTimeout: ApiConfig.TIMEOUT
      });

      if (response.responseCode === HttpStatus.OK) {
        const data = JSON.parse(response.result as string) as SingleUserResponse;
        this.log(`Successfully fetched user: ${data.data.email}`);
        return ResultFactory.success(UserDtoMapper.toDomain(data.data));
      } else if (response.responseCode === HttpStatus.NOT_FOUND) {
        this.logWarn(`User ${userId} not found`);
        return ResultFactory.failure(AppErrorFactory.apiNotFound(`User ${userId}`));
      } else {
        this.logError(`API error: ${response.responseCode}`);
        return ResultFactory.failure(AppErrorFactory.fromHttpStatus(response.responseCode));
      }
    } catch (error) {
      this.logError(`Network error fetching user: ${error}`);
      return ResultFactory.failure(this.handleError(error));
    }
  }

  async createUser(request: CreateUserRequest): Promise<Result<User, AppError>> {
    const url = `${ApiConfig.BASE_URL}${ApiEndpoints.USERS}`;
    const body = UserDtoMapper.toCreateDto(request);
    this.log(`Creating user at: ${url}`);

    try {
      const response = await this.httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: this.getHeaders(),
        extraData: JSON.stringify(body),
        connectTimeout: ApiConfig.TIMEOUT,
        readTimeout: ApiConfig.TIMEOUT
      });

      if (response.responseCode === HttpStatus.CREATED || response.responseCode === HttpStatus.OK) {
        const data = JSON.parse(response.result as string) as CreateUserResponseDto;
        this.log(`Successfully created user with ID: ${data.id}`);
        return ResultFactory.success(UserDtoMapper.createResponseToDomain(data, request));
      } else {
        this.logError(`API error creating user: ${response.responseCode}`);
        return ResultFactory.failure(AppErrorFactory.fromHttpStatus(response.responseCode));
      }
    } catch (error) {
      this.logError(`Network error creating user: ${error}`);
      return ResultFactory.failure(this.handleError(error));
    }
  }

  async updateUser(request: UpdateUserRequest): Promise<Result<User, AppError>> {
    const url = `${ApiConfig.BASE_URL}${ApiEndpoints.userById(request.id)}`;
    const body = UserDtoMapper.toUpdateDto(request);
    this.log(`Updating user ${request.id} at: ${url}`);

    try {
      const response = await this.httpRequest.request(url, {
        method: http.RequestMethod.PUT,
        header: this.getHeaders(),
        extraData: JSON.stringify(body),
        connectTimeout: ApiConfig.TIMEOUT,
        readTimeout: ApiConfig.TIMEOUT
      });

      if (response.responseCode === HttpStatus.OK) {
        const data = JSON.parse(response.result as string) as UpdateUserResponseDto;
        this.log(`Successfully updated user ${request.id}`);
        return ResultFactory.success(UserDtoMapper.updateResponseToDomain(data, request));
      } else if (response.responseCode === HttpStatus.NOT_FOUND) {
        this.logWarn(`User ${request.id} not found for update`);
        return ResultFactory.failure(AppErrorFactory.apiNotFound(`User ${request.id}`));
      } else {
        this.logError(`API error updating user: ${response.responseCode}`);
        return ResultFactory.failure(AppErrorFactory.fromHttpStatus(response.responseCode));
      }
    } catch (error) {
      this.logError(`Network error updating user: ${error}`);
      return ResultFactory.failure(this.handleError(error));
    }
  }

  async deleteUser(userId: number): Promise<Result<void, AppError>> {
    const url = `${ApiConfig.BASE_URL}${ApiEndpoints.userById(userId)}`;
    this.log(`Deleting user ${userId} at: ${url}`);

    try {
      const response = await this.httpRequest.request(url, {
        method: http.RequestMethod.DELETE,
        header: this.getHeaders(),
        connectTimeout: ApiConfig.TIMEOUT,
        readTimeout: ApiConfig.TIMEOUT
      });

      if (response.responseCode === HttpStatus.NO_CONTENT || response.responseCode === HttpStatus.OK) {
        this.log(`Successfully deleted user ${userId}`);
        return ResultFactory.success(undefined);
      } else if (response.responseCode === HttpStatus.NOT_FOUND) {
        this.logWarn(`User ${userId} not found for deletion`);
        return ResultFactory.failure(AppErrorFactory.apiNotFound(`User ${userId}`));
      } else {
        this.logError(`API error deleting user: ${response.responseCode}`);
        return ResultFactory.failure(AppErrorFactory.fromHttpStatus(response.responseCode));
      }
    } catch (error) {
      this.logError(`Network error deleting user: ${error}`);
      return ResultFactory.failure(this.handleError(error));
    }
  }

  @preDestroy()
  destroy(): void {
    this.httpRequest.destroy();
  }

  private getHeaders(): Record<string, string> {
    const headers: Record<string, string> = {};
    headers['Content-Type'] = ApiHeaders.CONTENT_TYPE;
    headers['Accept'] = ApiHeaders.ACCEPT;
    headers[ApiHeaders.API_KEY_HEADER] = ApiConfig.API_KEY;
    return headers;
  }

  private handleError(error: Error | Object): AppError {
    if (error instanceof Error) {
      const message = error.message.toLowerCase();
      if (message.includes('timeout')) {
        return AppErrorFactory.networkTimeout();
      } else if (message.includes('network') || message.includes('connection')) {
        return AppErrorFactory.noConnection();
      }
      return AppErrorFactory.networkError(error.message, error);
    }
    return AppErrorFactory.unknown();
  }

  private log(message: string): void {
    if (this.logger) {
      this.logger.d(TAG, message);
    }
  }

  private logWarn(message: string): void {
    if (this.logger) {
      this.logger.w(TAG, message);
    }
  }

  private logError(message: string): void {
    if (this.logger) {
      this.logger.e(TAG, message);
    }
  }
}
